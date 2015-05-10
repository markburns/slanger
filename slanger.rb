# encoding: utf-8
require 'bundler/setup'

require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'active_support/core_ext/string'
require File.join(File.dirname(__FILE__), 'lib', 'slanger', 'version')

module Slanger; end
module Slanger::Presence; end

EM.epoll
EM.kqueue

File.tap do |f|
  Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'slanger', '*.rb'))].each do |file|
    Slanger.autoload File.basename(file, '.rb').camelize, file
  end

  Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'slanger', "presence", '*.rb'))].each do |file|
    Slanger::Presence.autoload File.basename(file, '.rb').camelize, file
  end
end
