module Bootstrapper

  # == Bootstrapper::SSHSession
  # A wrapper around Net::SSH connection.
  class SSHSession

    attr_reader :connection_options
    attr_reader :ui

    def log
      Chef::Log
    end

    def initialize(ui, config=nil, &config_block)
      @ui = ui
      @connection_options = config || Config.new
      configure(&config_block) if block_given?
    end

    def configure
      yield connection_options
    end

    def connect
      log.debug "Connecting to cloud_server: #{ssh_options}"
      Net::SSH.start(*ssh_options) do |ssh|
        yield SSHSessionController.new(ui, ssh, connection_options)
      end
    end

    def ssh_options
      pp :host => connection_options.host
      connection_options.to_net_ssh_config
    end
  end
end
