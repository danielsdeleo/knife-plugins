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
      data_bag_file = repo_file("data_bags/environments/#{environment}.json")
      ui.msg(data_bag_file)
      exec "#{ENV['EDITOR']} #{data_bag_file}"
    end
  end

end
