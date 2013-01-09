module Bootstrapper

  class Config

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
end
