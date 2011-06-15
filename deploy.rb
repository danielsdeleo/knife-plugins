require File.expand_path('../lib/opscode_deploy', __FILE__)

module OpscodeDeploy
  class Deploy < Chef::Knife
    include EnvironmentNames

    category "OPSCODE DEPLOYMENT"

    banner "knife deploy [ROLE-ISH|QUERY]"
    
    deps do
      require 'yajl'
    end

    def run
      get_env_from_args!
      assert_git_rev_matches_remote
      project_spec = name_args[0]
      query = query_for_project_spec
      nodes = query_nodes(query)
      cookbooks = cookbooks_for_nodes(nodes)
      exit 0
    end

    def assert_git_rev_matches_remote
      deploy_config = Chef::Config[:deploy][environment]
      remote = deploy_config[:remote]
      branch = deploy_config[:branch]
      local_sha = `git rev-parse HEAD`.chomp
      remote_sha = `git ls-remote #{remote} #{branch}`[/^[0-9a-f]+/]
      if local_sha != remote_sha
        ui.error "your git repo is out of sync #{remote}/#{branch}"
        ui.msg "#{local_sha} (local)"
        ui.msg "#{remote_sha} (remote)"
        exit 1
      end
    end

    def query_for_project_spec
      query = case spec = name_args[0]
              when /:/
                spec
              else
                "role:#{role_from_rolish(spec)}"
              end
      "app_environment:#{environment} AND #{query}"
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
      run_list = nodes.inject(rr) do |rr, n|
        n.run_list.to_a.each {|ri| rr << ri}
        rr
      end
      # FIXME: verify this API works, technically it is expecting an
      # expanded run_list, but it makes sense to have the API expand
      # it since otherwise we will ask the API to expand it.  now post
      # to environments/_default/cookbook_versions with body of
      # run_list
    end
    
  end
end
