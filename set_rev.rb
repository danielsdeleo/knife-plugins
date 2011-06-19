require File.expand_path('../lib/opscode_deploy', __FILE__)

module OpscodeDeploy
  class SetRev < Chef::Knife
    include EnvironmentNames

    category "OPSCODE DEPLOYMENT"

    banner "knife set rev PROJECT REVISION"

    deps do
      require 'yajl'
    end

    def env_dbag_file
      repo_file("data_bags/environments/#{environment}.json")
    end

    def assert_order_preserving_hashes
      if RUBY_VERSION !~ /^1\.9/
        ui.error "Ruby 1.9 required so you don't reorder hashes (found: Ruby #{RUBY_VERSION})"
        exit 1
      end
    end

    def run
      assert_order_preserving_hashes
      get_env_from_args!
      @project, @rev = name_args[0], name_args[1]
      if @project.nil? || @rev.nil?
        ui.message "provide a project and a revision yo"
        exit 1
      end
      env_dbag_data = Yajl::Parser.parse(IO.read(env_dbag_file))
      project_keys = env_dbag_data.keys.grep(/.*#{@project}.*\-revision/)
      @project_key = case project_keys.size
      when 1
        project_keys.first
      when 0
        ui.error "No project matches the name #@project"
      else
        ui.msg "Multiple projects match #@project, pick one:"
        ui.highline.choose(project_keys)
      end
      ui.msg "#@project_key #{env_dbag_data[@project_key]} => #@rev"

      env_dbag_data[@project_key] = @rev
      File.open(env_dbag_file, "w"){|f| f.puts(Yajl::Encoder.encode(env_dbag_data, :pretty => true))}

      git_commit_pid = fork do
        Dir.chdir(repo_file(""))
        exec "git commit -v -e -m 'Bump #{environment} #@project_key from #{env_dbag_data[@project_key]} to #@rev' data_bags/environments/#{environment}.json"
      end
      pid, status = Process.waitpid2(git_commit_pid)

      if status.success?
        git_push_pid = fork do
          Dir.chdir(repo_file(""))
          ui.msg "Hey, don't forget to git push"
        end
      else
        ui.error "Commit failed, exiting"
        exit 1
      end
    end

  end
end
