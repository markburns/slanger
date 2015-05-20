require "logger"

module Slanger
  module Logger
  end

  class << self
    attr_writer :logger

    def logger
      @logger ||= ::Logger.new STDOUT
    end

    def log_level=(level)
      if level.is_a?(String)
        level = ::Logger.const_get level.upcase
      end

      logger.level = level
    end

    %w(info debug warn error).each do |m|
      define_method(m) do |msg|
        stack = get_lines_from caller[0..4]

        if ENV["SLIM_LOG"]
          msg = "\n#{msg}\n"
          puts msg

        else

          if msg =~ /\ASPEC/i
            msg = "\n#{msg}"
          else
            msg = "\n#{stack}\n#{msg}\n"
          end

          if ENV["DEBUGGER"]
            klass = binding.of_caller(1).eval('self.class')
            meth  = binding.of_caller(1).eval('__method__')
            if klass.name =~/RSpec/
              msg = "node-#{Slanger::Service.node_id} #{msg}\n"
            else
              msg = "node-#{Slanger::Service.node_id} #{klass}##{meth}#{msg}\n\n"
            end
          end
          if ["LOG_NO_TIMESTAMPS"]
            puts msg
          else
            logger.send(m, msg)
          end
        end
      end

    end

    def get_lines_from(array)
      array.map{|l| get_line_summary_from(l)}.join "  "
    end

    def get_line_summary_from(line)
      path, line_number, _ = line.split(":")
      filenames = Pathname.new(path).each_filename.to_a
      lib_index = filenames.each_index.find{|i| filenames[i] == 'lib' && filenames.include?("slanger")} || -3
      filename = filenames[lib_index..-1].join "/" rescue ""

      if filename && filename["slanger/spec"]
        filename.gsub! /\Aslanger\//, ""
      end

      "#{filename}:#{line_number}"
    end
  end
end
