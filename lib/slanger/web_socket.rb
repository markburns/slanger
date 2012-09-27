require 'ruby-debug'
module Slanger::WebSocket
  f = File
  Dir[f.expand_path(f.join(f.dirname(__FILE__), 'web_socket', '*.rb'))].each do |file|
    base = File.basename(file, '.rb')
    autoload base.camelize.to_sym, file
  end
end


