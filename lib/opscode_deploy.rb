module OpscodeDeploy
  module EnvironmentNames
    attr_reader :environment

    def get_env_from_args!
      unless @environment = config[:opscode_environment] || guess_env_name
        ui.error "Environment to edit could not be determined by magic and you did not provide one"
        exit 1
      end
    end

    def guess_env_name
      env_dir = File.basename(repo_path)
      if File.exist?(repo_file("data_bags/environments/#{env_dir}.json"))
        env_dir
      else
        nil
      end
    end

    def repo_path
      cookbook_parent = File.expand_path("..", Chef::Config.cookbook_path.first)
      if File.directory?(File.join(cookbook_parent, "data_bags"))
        cookbook_parent
      elsif File.directory?(File.join(Dir.pwd, "data_bags"))
        Dir.pwd
      else
        File.join(Dir.pwd, 'chef-repo')
      end
    end

    # Takes a relative path and expands it relative to your chef-repo
    # Looks for data_bags in cwd, if found then assume we are in the
    # chef-repo, otherwise look for 'chef-repo'
    def repo_file(relative_path)
      File.expand_path(relative_path, repo_path)
    end
  end
end
