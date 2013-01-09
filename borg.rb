module Kallistec

  class Borg < Chef::Knife

    deps do
      require 'net/ssh'
      require 'net/scp'


      $:.unshift File.expand_path("../lib", __FILE__)
      require "bootstrapper"
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
      pp :name_args => @name_args
      @name_args[0]
    end

    def log
      Chef::Log
    end

    def bootstrap
      bootstrapper = Bootstrapper::Controller.new(ui)
      bootstrapper.configure do |c|
        c.user = "ddeleo"
        c.password = "foobar"
        c.host = remote_host
      end

      bootstrapper.run
    end

  end
end

__END__
TODO:
  * inspect for all objects
  * pp for all objects
