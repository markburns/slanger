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
        path, line, _ = caller[0].split(":")
        filename = Pathname.new(path).each_filename.to_a[-3..-1].join "/" rescue ""
        msg  = "#{filename }:#{line} #{msg}"
        logger.send(m, msg)
      end
    end
  end
end
