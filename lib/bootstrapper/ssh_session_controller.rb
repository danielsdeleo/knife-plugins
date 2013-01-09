
module Bootstrapper
  # == Bootstrapper::SSHSession::SessionController
  # Wraps an SSH Session object and provides a simplified interface to
  # running commands and scp-ing files.
  #
  # The underlying session object can be accessed via #session.
  class SSHSessionController

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
end
