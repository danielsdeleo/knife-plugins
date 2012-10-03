module OpscodeDeploy
  module EnvironmentNames
    OC_ENVS = {'prod' => 'rs-prod', 'preprod' => 'rs-preprod'}

    attr_reader :environment

    def get_env_from_args!
      unless @environment = guess_env_name
        ui.error "Environment to edit could not be determined by magic and you did not provide one"
        exit 1
      end
    end

    def guess_env_name
      pwd = File.basename(Dir.pwd)
      if OC_ENVS.key?(pwd)
        OC_ENVS[pwd]
      elsif OC_ENVS.key?(@name_args[0])
        @name_args[0]
      else
        nil
      end
    end

    # Takes a relative path and expands it relative to your chef-repo
    # Looks for data_bags in cwd, if found then assume we are in the
    # chef-repo, otherwise look for 'chef-repo'
    def repo_file(relative_path)
      if File.directory?("data_bags")
        File.expand_path(relative_path, Dir.pwd)
      else
        repo_path = File.expand_path('chef-repo', Dir.pwd)
        File.expand_path(relative_path, repo_path)
      end
    end
  end
end
