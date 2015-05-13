require "spec_helper"
require 'aruba'
require 'aruba/api'


describe "bin/slanger" do
  include Aruba::Api

  describe "YAML templates" do
    before do
      require 'pathname'

      root = Pathname.new(__FILE__).parent.parent.parent

      # Allows us to run commands directly, without worrying about the CWD
      ENV['PATH'] = "#{root.join('bin').to_s}#{File::PATH_SEPARATOR}#{ENV['PATH']}"
    end

    pending "should emit valid YAML to STDOUT" do
      run_simple <<-COMMAND
        bundle exec slanger --app_key  d4590800e2c6ae299652 \
        --secret   your-pusher-secret \
        --api_host 0.0.0.0:4568 \
        --websocket_host 0.0.0.0:8081 \
        --pid_file slanger-1.pid \
        --log_level debug \
        --log_file slanger-1.log
      COMMAND


    end
  end
end
