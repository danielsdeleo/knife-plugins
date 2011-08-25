require File.expand_path('../lib/opscode_deploy', __FILE__)

module OpscodeDeploy
  class ShowRev < Chef::Knife
    include EnvironmentNames

    category "OPSCODE DEPLOYMENT"

    banner "knife show rev PROJECT REVISION"

    deps do
      require 'yajl'
    end

    def env_dbag_file
      repo_file("data_bags/environments/#{environment}.json")
    end

    def run
      get_env_from_args!
      @project = name_args[0]
      if @project.nil?
        ui.error "provide a project and a revision yo"
        exit 1
      end
      env_dbag_data = Yajl::Parser.parse(IO.read(env_dbag_file))
      project_keys = env_dbag_data.keys.grep(/.*#{@project}.*\-revision/)
      selected_data = project_keys.inject({}) {|data, key| data[key] = env_dbag_data[key]; data}
      output(format_for_display(selected_data))
    end

  end
end
