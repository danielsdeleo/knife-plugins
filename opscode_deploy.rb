module OpscodeDeploy
  module EnvironmentNames
    OC_ENVS = {'rs-prod' => true, 'rs-preprod' => true}

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
        pwd
      elsif OC_ENVS.key?(@name_args[0])
        @name_args[0]
      else
        nil
      end
    end

    # Takes a relative path and expands it relative to your chef-repo
    def chef_repo(relative_path)
      repo_path = File.expand_path('chef-repo', Dir.pwd)
      File.expand_path(relative_path, repo_path)
    end
  end
end
