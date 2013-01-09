module Bootstrapper
  class Controller

    attr_accessor :config
    attr_accessor :config_installer
    attr_accessor :chef_installer
    attr_reader :ui

    def initialize(ui, &block)
      @ui = ui
      @config = Config.new
      @config_installer = ConfigInstaller.new
      @chef_installer = ChefInstaller.new
      configure(&block) if block_given?
    end

    def configure
      yield @config
    end

    def chef_api
      Chef::REST.new(Chef::Config[:chef_server_url])
    end

    def log
      Chef::Log
    end

    def run
      sanity_check

      create_client
      create_node

      prepare_installers
      ssh = configure_ssh_session

      ssh.connect do |session|
        log.debug "Installing config files"
        config_installer.install_config(session)
        log.debug "Executing installer..."
        chef_installer.install(session)
      end
    end

    def sanity_check
      # If the client or node exist, ask the user if they should be replaced.
    end

    def create_client
      return @client unless @client.nil?
      @client_name = Time.new.strftime("%Y-%M-%d-%H-%M-%S")
      api_response = chef_api.post('clients', :name => @client_name, :admin => false)
      @client = Chef::ApiClient.new.tap do |c|
        c.name @client_name
        c.admin false
        c.private_key api_response['private_key']
      end
      log.info "New client name: #{@client.name}"

      config_installer.install_file("client key", "client.pem") do |f|
        f.content = @client.private_key
        f.mode = "0600"
      end
      @client
    end

    def create_node
      # TODO: create node, setup run list.
      # must be done as the client created by previous step
    end

    def prepare_installers
      chef_installer = ChefInstaller.new
      chef_installer.setup_files(config_installer)
    end

    def configure_ssh_session
      @ssh ||= SSHSession.new(ui, config)
    end
  end
end
