module Kallistec

  class BorgConfig

    # config files
    # rel_path => content
  end

  class SSHSession
    class SessionWrapper

      class ExecuteFailure < ArgumentError
      end

      attr_reader :session

      def initialize(session)
        @session = session
      end

      def log
        Chef::Log
      end

      def run(cmd, desc=nil)
        log.info(desc) if desc
        log.debug "Executing remote command: #{cmd}"
        result = session.exec!(cmd)
        log.debug "result: #{cmd}"
      end

      def pty_run(command)
        ssh.open_channel do |channel|
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
        "sudo -p 'SUDO PASSWORD FOR #{remote_host_ip}:' #{cmd}"
      end

      def get_password
        @password ||= ui.ask("SUDO PASSWORD FOR #{remote_host_ip}") { |q| q.echo = false }
      end

      def remote_host
        raise "TODO"
      end

    end

    def connect
      log.debug "Connecting to cloud_server: #{ssh_options}"
      Net::SSH.start(*ssh_options) do |ssh|
        yield SessionWrapper.new(ssh)
      end
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

    def remote_host_ip
      @name_args[0]
    end

    def log
      Chef::Log
    end

    def ssh_options
      [
       remote_host_ip,
       'ddeleo',
       {:password => "foobar", :paranoid => false}
      ]
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
      StringIO.new(api_client.private_key)
    end

    def tempdir
      @tempdir ||= "/tmp/chef-bootstrap-#{rand(2 << 128).to_s(16)}"
    end

    def temp_path(rel_path)
      File.join(tempdir, rel_path)
    end

    def bootstrap
      log.debug "Connecting to cloud_server: #{ssh_options}"
      Net::SSH.start(*ssh_options) do |ssh|
        log.debug "Making config dir #{tempdir}"
        ssh.exec!("mkdir -m 0700 #{@tempdir}")



        log.debug "uploading client key"
        ssh.scp.upload! client_key, temp_path("client.pem")
        log.debug "uploading bootstrap script:"
        log.debug bootstrap_script.string
        ssh.scp.upload! bootstrap_script, temp_path("bootstrap.sh")

        log.debug "executing bootstrap..."
        ssh.open_channel do |channel|
          channel.request_pty
          channel.exec("sudo -p 'SUDO PASSWORD FOR #{remote_host_ip}:' bash #{temp_path("bootstrap.sh")}") do |ch, success|
            raise ArgumentError, "Cannot execute #{command}" unless success
            ch.on_data do |ichannel, data|
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

      end
    end

    def get_password
      @password ||= ui.ask("SUDO PASSWORD FOR #{remote_host_ip}") { |q| q.echo = false }
    end


    def client_rb
      "foo"
    end

    def bootstrap_script
      StringIO.new(<<-END)
set -x
ls -la #{tempdir}
mkdir -m 0700 /etc/chef
chown root:root /etc/chef
chmod 0755 /etc/chef
mv #{temp_path("client.pem")} /etc/chef/client.pem
chown root:root /etc/chef/client.pem
chmod 0600 /etc/chef/client.pem
bash <(wget http://opscode.com/chef/install.sh --no-check-certificate -O -) -v 10.16.4
END
    end

    def bootstrap_context
      Chef::Knife::Core::BootstrapContext.new(bootstrap_config, run_list, chef_config)
    end

    def node
      @node ||= Chef::Node.new.tap {|n| n.name(client.name)}
    end



  end
end
