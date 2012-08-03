require 'chef/knife'

module Kallistec
  class KeyCheck < Chef::Knife

    deps do
      require 'openssl'
    end

    banner 'knife key check CLIENT PATH_TO_private_key_file'

    def run
      unless @client_name = name_args[0] and @private_key_file = name_args[1]
        show_usage
        exit 1
      end
      @private_key_file = File.expand_path(@private_key_file)
      unless File.exist?(@private_key_file)
        ui.error "No such file for private key: #{@private_key_file}"
        exit 1
      end

      @auth_creds = Chef::REST::AuthCredentials.new(@client_name, @private_key_file)
      @private_key = @auth_creds.key
      #extract the public key from the private key:
      @public_key_from_local = @private_key.public_key

      @public_key_from_server = fetch_public_from_server
      if @public_key_from_local.to_s == @public_key_from_server.to_s
        ui.msg "Match."
        ui.msg "#{@private_key_file} is a valid key for client #{@client_name}"
      else
        ui.msg "Mismatch:"
        ui.msg "Public key extracted from private key:\n#{@public_key_from_local}"
        ui.msg "Public key from server:\n#{@public_key_from_server}"
        exit 1
      end

    end

    def fetch_public_from_server
      api_client = Chef::REST.new(Chef::Config[:chef_server_url])
      client_info = api_client.get_rest("clients/#{@client_name}")
      if client_info.has_key?("certificate")
        OpenSSL::X509::Certificate.new(client_info["certificate"]).public_key
      elsif client_info.has_key?("public_key")
        OpenSSL::PKey::RSA.new(client_info["public_key"])
      else
        ui.error "The server did not return a cert or public key for this client, cannot verify key."
        exit 1
      end
    end

  end

end
