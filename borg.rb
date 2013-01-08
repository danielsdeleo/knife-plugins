module Kallistec

  class SSHSession
    class SessionWrapper

      class ExecuteFailure < ArgumentError
      end

      attr_reader :session
      attr_reader :ssh_config
      attr_reader :ui

      def initialize(ui, session, ssh_config)
        @ui = ui
        @session = session
        @ssh_config = ssh_config
      end

      def log
        Chef::Log
      end

      def scp(io_or_string, path)
        io = if io_or_string.respond_to?(:read_nonblock)
               io_or_string
             else
               StringIO.new(io_or_string)
             end
        session.scp.upload!(io, path)
      end

      def run(cmd, desc=nil)
        log.info(desc) if desc
        log.debug "Executing remote command: #{cmd}"
        result = session.exec!(cmd)
        log.debug "result: #{cmd}"
      end

      def pty_run(command)
        exit_status = nil
        session.open_channel do |channel|
          channel.request_pty
          channel.exec(command) do |ch, success|
            raise ExecuteFailure, "Cannot execute (on #{remote_host}) command `#{command}'" unless success
            ch.on_data do |ichannel, data|
              # TODO: stream this the right way.
              puts("READ: #{data}")
              if data =~ /^SUDO PASSWORD FOR/
                ichannel.send_data("#{get_password}\n")
              end
            end
            ch.on_request "exit-status" do |ichannel, data|
              exit_status = data.read_long
            end
          end
        end
        exit_status
      end

      def sudo(cmd)
        "sudo -p 'SUDO PASSWORD FOR #{remote_host}:' #{cmd}"
      end

      def get_password
        @password ||= ui.ask("SUDO PASSWORD FOR #{remote_host}") { |q| q.echo = false }
      end

      def remote_host
        ssh_config.host
      end

    end

    class ConnectionOptions
      attr_accessor :host
      attr_accessor :port

      attr_accessor :user
      attr_accessor :password
      attr_accessor :identity_file

      attr_accessor :gateway
      attr_accessor :paranoid

      def to_net_ssh_config
        [
         host,
         user,
         {:password => password, :paranoid => paranoid}
        ]
      end
    end

    attr_reader :connection_options
    attr_reader :ui

    def log
      Chef::Log
    end

    def initialize(ui, connection_opts=nil, &config_block)
      @ui = ui
      @connection_options = connection_opts || ConnectionOptions.new
      configure(&config_block) if block_given?
    end

    def configure
      yield connection_options
    end

    def connect
      log.debug "Connecting to cloud_server: #{ssh_options}"
      Net::SSH.start(*ssh_options) do |ssh|
        yield SessionWrapper.new(ui, ssh, connection_options)
      end
    end

    def ssh_options
      connection_options.to_net_ssh_config
    end
  end

  class ConfigInstaller

    class ConfigFile
      attr_reader :description
      attr_reader :rel_path

      attr_accessor :content
      attr_accessor :mode

      def initialize(description, rel_path)
        @description = description
        @rel_path = rel_path
        @content = ""
        @mode = "0600"
      end
    end

    attr_reader :files_to_install

    def initialize
      @files_to_install = []
    end

    def log
      Chef::Log
    end

    def install_file(description, rel_path)
      file = ConfigFile.new(description, rel_path)
      yield file if block_given?
      @files_to_install << file
    end

    def install_config(ssh_session)
      stage_files(ssh_session)
      install_staged_files(ssh_session)
    end

    def stage_files(ssh_session)
      log.debug "Making config staging dir #{tempdir}"
      ssh_session.run("mkdir -m 0700 #{@tempdir}")

      files_to_install.each do |file|
        staging_path = temp_path(file.rel_path)
        log.debug "Staging #{file.description} to #{staging_path}"
        ssh_session.scp(file.content, staging_path)
      end
    end

    def install_staged_files(ssh_session)
      log.debug("Creating Chef config directory /etc/chef")
      # TODO: don't hardcode sudo
      ssh_session.pty_run(ssh_session.sudo(<<-SCRIPT))
bash -c '
  mkdir -p -m 0700 /etc/chef
  chown root:root /etc/chef
  chmod 0755 /etc/chef
'
SCRIPT
      files_to_install.each do |file|
        # TODO: support paths outside /etc/chef?
        final_path = File.join("/etc/chef", file.rel_path)
        log.debug("moving staged #{file.description} to #{final_path}")

        # TODO: don't hardcode sudo
        ssh_session.pty_run(ssh_session.sudo(<<-SCRIPT))
bash -c '
  mv #{temp_path(file.rel_path)} #{final_path}
  chown root:root #{final_path}
  chmod #{file.mode} #{final_path}
'
SCRIPT
      end
    end

    def tempdir
      @tempdir ||= "/tmp/chef-bootstrap-#{rand(2 << 128).to_s(16)}"
    end

    def temp_path(rel_path)
      File.join(tempdir, rel_path)
    end

  end

  class ChefInstaller

    def setup_files(config_installer)
      config_installer.install_file("bootstrap script", "bootstrap.sh") do |f|
        f.content = install_script
        f.mode = "0755"
      end
    end

    def install_script
      <<-SCRIPT
set -x
bash <(wget http://opscode.com/chef/install.sh --no-check-certificate -O -) -v 10.16.4
SCRIPT
    end

    def install(ssh_session)
      ssh_session.pty_run(ssh_session.sudo("bash -x /etc/chef/bootstrap.sh"))
    end
  end

  class Borg < Chef::Knife

    deps do
      require 'net/ssh'
      require 'net/scp'
    end

    option :ssh_user,
      :short => "-x USERNAME",
      :long => "--ssh-user USERNAME",
      :description => "The ssh username"

    option :ssh_password,
      :short => "-P PASSWORD",
      :long => "--ssh-password PASSWORD",
      :description => "The ssh password"

    option :ssh_port,
      :short => "-p PORT",
      :long => "--ssh-port PORT",
      :description => "The ssh port",
      :proc => Proc.new { |key| Chef::Config[:knife][:ssh_port] = key }

    option :ssh_gateway,
      :short => "-G GATEWAY",
      :long => "--ssh-gateway GATEWAY",
      :description => "The ssh gateway",
      :proc => Proc.new { |key| Chef::Config[:knife][:ssh_gateway] = key }

    option :identity_file,
      :short => "-i IDENTITY_FILE",
      :long => "--identity-file IDENTITY_FILE",
      :description => "The SSH identity file used for authentication"

    option :host_key_verify,
      :long => "--[no-]host-key-verify",
      :description => "Verify host key, enabled by default.",
      :boolean => true,
      :default => true

    def run
      bootstrap
    end

    def remote_host
      @name_args[0]
    end

    def log
      Chef::Log
    end

    def ssh_options
    end

    def chef_api
      Chef::REST.new(Chef::Config[:chef_server_url])
    end

    def api_client
      return @client unless @client.nil?
      @client_name = Time.new.strftime("%Y-%M-%d-%H-%M-%S")
      api_response = chef_api.post('clients', :name => @client_name, :admin => false)
      @client = Chef::ApiClient.new.tap do |c|
        c.name @client_name
        c.admin false
        c.private_key api_response['private_key']
      end
      log.info "New client name: #{@client.name}"
      @client
    end

    def client_key
      api_client.private_key
    end

    def bootstrap
      config_installer = ConfigInstaller.new

      config_installer.install_file("client key", "client.pem") do |f|
        f.content = client_key
        f.mode = "0600"
      end


      chef_installer = ChefInstaller.new
      chef_installer.setup_files(config_installer)

      ssh = SSHSession.new(ui) do |config|
        config.user = "ddeleo"
        config.password = "foobar"
        config.host = remote_host
      end

      log.debug "Connecting to cloud_server: #{ssh_options}"

      ssh.connect do |session|
        log.debug "Installing config files"
        config_installer.install_config(session)
        log.debug "Executing installer..."
        chef_installer.install(session)
      end
    end

  end
end
