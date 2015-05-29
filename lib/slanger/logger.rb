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
      method_body = ""

      if ENV["LOG_PUTS"]
        method_body << <<-CODE
        return puts msg 
        CODE
      end

      if ENV["LOG_STACK"]
        method_body << <<-CODE
          if msg =~ /\ASPEC/i
            msg = "\n#{msg}"
          else
            stack = get_lines_from caller[0..4]
            msg = "\n#{stack}\n#{msg}\n"
          end
        CODE
      end

      method_body << <<-CODE
        klass = nil
      CODE

      if ENV["LOG_CALLER"]
        method_body << <<-CODE
          klass = binding.of_caller(1).eval('self.class')
          meth  = binding.of_caller(1).eval('__method__')
          if klass.name =~/RSpec/
            msg = "#{msg}\n"
          else
            msg = " #{klass}##{meth}#{msg}\n\n"
          end
        CODE
      end

      if ENV["LOG_NODE_ID"]
        method_body << <<-CODE
        if klass.to_s !~ /RSpec/
          msg = "node-#{Slanger::Service.node_id} #{msg}\n\n"
        end
        CODE
      end


      method_body << <<-CODE
        logger.send(:#{m}, msg)
      CODE

      method_body = <<-METHOD
        def #{m}(msg)
          #{method_body}
        end
      METHOD

      eval method_body
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
