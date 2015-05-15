# encoding: utf-8
require 'bundler/setup'

require 'eventmachine'
require 'em-hiredis'
require "redis"
require 'rack'
require 'active_support/core_ext/string'
require File.join(File.dirname(__FILE__), 'lib', 'slanger', 'version')

module Slanger; end
module Slanger::Presence; end

EM.epoll
EM.kqueue

File.tap do |f|
  auto = ->(constant, *path) {
    Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'slanger', *path, '*.rb'))].each do |file|
      constant.autoload File.basename(file, '.rb').camelize, file
    end
  }

  auto.(Slanger)
  auto.(Slanger::Presence, "presence")
  auto.(Slanger::Api,      "api"     )
  auto.(Slanger::Janitor, "janitor"  )
end
