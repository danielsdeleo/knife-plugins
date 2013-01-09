
module Bootstrapper

  # == Bootstrapper::ChefInstaller
  # Installs chef on the remote machine.
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
end
