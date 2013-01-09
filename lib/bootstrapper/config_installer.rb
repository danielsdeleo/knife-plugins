module Bootstrapper

  # == Bootstrapper::ConfigInstaller
  # Manages a collection of file descriptions to be installed on the remote
  # node, and installs them via scp+ssh.
  #
  # Files are installed in a two stage process. First, files are staged to a
  # staging directory in /tmp, then they are moved to the final location in
  # /etc/chef.
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

end
