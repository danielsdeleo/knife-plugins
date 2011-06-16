require File.expand_path('../lib/opscode_deploy', __FILE__)

module OpscodeDeploy
  class Deploy < Chef::Knife
    include EnvironmentNames

    category "OPSCODE DEPLOYMENT"

    banner "knife deploy [ROLE-ISH|QUERY]"
    
    deps do
      require 'yajl'
      require 'chef/search/query'
      require 'chef/cookbook_version'
      require 'chef/checksum_cache'
      require 'chef/knife/ssh'
      require 'net/ssh'
      require 'net/ssh/multi'
      require 'set'
      require 'pp'
    end

    def run
      get_env_from_args!
      assert_git_rev_matches_remote
      project_spec = name_args[0]
      query = query_for_project_spec
      nodes = find_nodes(query)
      remote_cookbooks = cookbooks_for_nodes(nodes)
      local_cookbooks = cookbooks_from_repo(remote_cookbooks[:names])
      compare_cookbooks(local_cookbooks, remote_cookbooks)
      # FIXME: eventually, we will want to support many of the knife
      # ssh options
      knife_ssh = Chef::Knife::Ssh.new
      knife_ssh.config[:manual] = true
      knife_ssh.name_args = [nodes.map(&:fqdn).join(" "), "tmux"]
      knife_ssh.run
      exit 0
    end

    def git_branch
      @git_branch ||= deploy_config[:branch]
      required_config(":branch", @git_branch)
    end
    
    def git_remote
      @git_remote ||= deploy_config[:remote]
      required_config(":remote", @git_remote)
    end
    
    def deploy_config
      @deploy_config ||= (Chef::Config[:deploy][environment] rescue nil)
      if @deploy_config.nil? || !@deploy_config.is_a?(Hash)
        ui.error "missing deploy({#{environment} => {...}}) section in knife.rb"
        exit 1
      end
      @deploy_config
    end

    def required_config(label, value)
      if value.nil?
        ui.error "missing key deploy({#{environment} => {#{label} => ???}}) in knife.rb"
        exit 1
      end
      value
    end
    
    def assert_git_rev_matches_remote
      local_sha = `git rev-parse HEAD`.chomp
      remote_sha = `git ls-remote #{git_remote} #{git_branch}`[/^[0-9a-f]+/]
      if local_sha != remote_sha
        ui.error "your git repo is out of sync #{git_remote}/#{git_branch}"
        ui.msg "#{local_sha} (local)"
        ui.msg "#{remote_sha} (remote)"
        exit 1
      end
    end

    def find_nodes(query)
      searcher = Chef::Search::Query.new
      rows, _start, _total = searcher.search(:node, query)
      if rows.empty?
        ui.error "No nodes matched the query: #{query}"
        exit 1
      end
      rows
    end

    def query_for_project_spec
      query = case spec = name_args[0]
              when /:/
                spec
              else
                "role:#{role_from_rolish(spec)}"
              end
      "app_environment:#{environment} AND (#{query})"
    end

    def role_from_rolish(spec)
      role_matches = Dir.glob("#{repo_file("roles")}/*#{spec}*.json").map do |f|
        File.basename(f, ".json")
      end
      case role_matches.size
      when 1
        role_matches.first
      when 0
        ui.error "No roles matched '#{spec}' in roles dir #{repo_file("roles")}"
        exit 1
      else
        # choice?
        ui.msg "Multiple role matches for '#{spec}', pick one:"
        choice = ui.highline.choose(*(role_matches.push("oops, nevermind")))
        if choice == "oops, nevermind"
          exit 0
        end
        choice
      end
    end

    def cookbooks_for_nodes(nodes)
      run_list = nodes.inject(nodes.first.run_list) do |list, node|
        node.run_list.to_a.each { |ri| list << ri }
        list
      end
      chef_rest = Chef::REST.new(Chef::Config[:chef_server_url])
      # FIXME: customize for real environments
      path = "environments/_default/cookbook_versions"
      cookbook_versions = chef_rest.post_rest(path,
                             {"run_list" => run_list})
      file_checksums = {}
      checksums_for_cookbooks(cookbook_versions.values)
    end

    def checksums_for_cookbooks(cookbook_versions)
      file_checksums = {}
      cookbook_versions.each do |cookbook_version|
        Chef::CookbookVersion::COOKBOOK_SEGMENTS.each do |segment|
          cookbook_version.manifest[segment].each do |file|
            file_checksums["#{cookbook_version.name}/#{file["path"]}"] = file["checksum"]
          end
        end
      end
      {
        :names => cookbook_versions.map { |cv| cv.name.to_s }.sort,
        :checksums => file_checksums
      }
    end

    def cookbooks_from_repo(names)
      cookbook_versions = []
      names.each do |name|
        cookbook_path = repo_file("cookbooks/#{name}")
        cvl = Chef::Cookbook::CookbookVersionLoader.new(cookbook_path)
        cvl.load_cookbooks
        cookbook_version = cvl.cookbook_version
        # will get nil if no such cookbook in local repo
        if cookbook_version
          cookbook_versions << cookbook_version
        end
      end
      checksums_for_cookbooks(cookbook_versions)
    end

    def compare_cookbook_names(local, remote)
      if local[:names] != remote[:names]
        only_local, only_remote = difference_report(local[:names], remote[:names])
        ui.error "Local cookbook repo does not match server"
        if !only_local.empty?
          ui.msg "The following cookbooks are not on the server:"
          only_local.each { |c| ui.msg "\t#{c}" }
        end
        if !only_remote.empty?
          ui.msg "The following cookbooks are not in your cookbooks dir:"
          only_remote.each { |c| ui.msg "\t#{c}" }
        end
        false
      end
      true
    end

    def compare_cookbook_files(local, remote)
      local_files = local[:checksums].keys.sort
      remote_files = remote[:checksums].keys.sort
      they_match = true
      only_local, only_remote = difference_report(local_files, remote_files)
      if !only_local.empty?
        they_match = false
        ui.msg "The following cookbook files are not on the server:"
        only_local.each { |c| ui.msg "\t#{c}" }
      end
      if !only_remote.empty?
        they_match = false
        ui.msg "The following cookbook files are not in your cookbooks dir:"
        only_remote.each { |c| ui.msg "\t#{c}" }
      end
      mismatches = []
      local_files.each do |file|
        if local[:checksums][file] != remote[:checksums][file]
          mismatches << file
        end
      end
      if !mismatches.empty?
        they_match = false
        ui.error "mismatches!"
        mismatches.each { |m| ui.msg m }
      end
      they_match
    end
    
    def compare_cookbooks(local, remote)
      names_match = compare_cookbook_names(local, remote)
      files_match = compare_cookbook_files(local, remote)
      exit 1 unless (names_match && files_match)
    end

    def difference_report(a, b)
      a_set = Set.new(a)
      b_set = Set.new(b)
      only_a = a_set.difference(b_set)
      only_b = b_set.difference(a_set)
      [only_a, only_b]
    end
  end
end
