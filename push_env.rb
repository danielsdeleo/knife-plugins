require File.expand_path('../opscode_deploy', __FILE__)

module OpscodeDeploy
  class PushEnv < Chef::Knife
    include EnvironmentNames

    category "OPSCODE DEPLOYMENT"

    K = Chef::Knife

    banner "knife env push OPSCODE_ENV"

    deps do
      require 'chef/knife/data_bag_from_file'
      K::DataBagFromFile.load_deps
    end

    def run
      get_env_from_args!

      dbff = K::DataBagFromFile.new
      dbff.name_args = %W{environments chef-repo/data_bags/environments/#{environment}.json}
      dbff.run

    end
  end

end
