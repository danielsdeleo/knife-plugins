require File.expand_path('../opscode_deploy', __FILE__)

module OpscodeDeploy
  class EditEnv < Chef::Knife
    include EnvironmentNames

    category "OPSCODE DEPLOYMENT"

    banner "knife edit env [OPSCODE_ENV]"

    deps do
    end

    def run
      get_env_from_args!
      exec "#{ENV['EDITOR']} chef-repo/data_bags/environments/#{environment}.json"
    end
  end

end
