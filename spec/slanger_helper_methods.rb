module SlangerHelperMethods
  def start_slanger options={}, &blk
    # Fork service. Our integration tests MUST block the main thread because we
    # want to wait for i/o to finish.
    fork_reactor do |channel|
      blk.call if blk
      options = default_slanger_options.merge(options)
      Slanger::Config.load options

      start_websocket_server! options
      start_api_server! options
    end

    Slanger.debug "SPEC server_pids #{server_pids} "
    wait_for_slanger options
  end

  def fork_reactor
    server_pids <<  EM.fork_reactor do
      yield
    end
  end

  def server_pids
    @server_pids ||= []
  end

  def default_slanger_options 
    { host:             '0.0.0.0',
      api_port:         '4567',
      websocket_port:   '8080',
      app_key:          '765ec374ae0a69f4ce44',
      secret:           'your-pusher-secret',
      activity_timeout: 100
    }
  end

  def start_websocket_server!(options)
    ws_options = Slanger::Service.map_options_for_websocket_server options
    Slanger::WebSocketServer.run(ws_options)
  end

  def start_api_server!(options)
    Thin::Logging.silent = true
    api_server_options = Slanger::Service.map_options_for_api_server options
    Rack::Handler::Thin.run Slanger::ApiServer, api_server_options
  end

  def stop_slanger
    server_pids.each do |pid|
      # Ensure Slanger is properly stopped. No orphaned processes allowed!
      Process.kill 'SIGKILL', pid
      Process.wait pid
    end
  end

  def wait_for_slanger opts = {}
    opts = default_slanger_options.merge opts
    wait_for_socket(opts[:api_port])
    wait_for_socket(opts[:websocket_port])
  end

  def wait_for_socket(port)
    retry_count = 100
    puts "Waiting for slanger on port #{port}..."
    begin
      TCPSocket.new('0.0.0.0', port).close
    rescue
      retry_count -= 1
      sleep 0.015

      if retry_count > 0
        retry
      else
        fail "Slanger start failed connecting to port: #{port}"
      end
    end

  end

  def new_websocket opts = {}
    opts = { key: Pusher.key, protocol: 7 }.update opts
    uri = "ws://0.0.0.0:8080/app/#{opts[:key]}?client=js&version=1.8.5&protocol=#{opts[:protocol]}"

    Slanger.debug "SPEC Create new websocket #{uri}"
    ws = EM::HttpRequest.new(uri).get :keepalive => true
    ws.stream{ |msg|
      Slanger.error "SPEC Default stream output: #{msg}"

    } #ensure a default empty stream is provided

    ws
  end

  def em_stream opts = {}
    messages = []

    em_thread do
      websocket = new_websocket opts

      stream(websocket, messages) do |message|
        yield websocket, messages
      end
    end

    return messages
  end

  def em_thread
      # do something and raise exception
      EM.run do
        yield
      end

  end

  def stream websocket, messages
    websocket.stream do |message|
      Slanger.debug "SPEC message received #{message}"
      messages << JSON.parse(message)

      yield message
    end
  end

  def send_subscribe options
    info      = { user_id: options[:user_id], user_info: { name: options[:name] } }
    socket_id = JSON.parse(options[:message]['data'])['socket_id']
    websocket = options[:user]

    subscribe_to_presence_channel(websocket, info, socket_id)
  end


  def subscribe_to_presence_channel websocket, user_info, socket_id

    digest = OpenSSL::Digest::SHA256.new
    to_sign   = [socket_id, 'presence-channel', user_info.to_json].join ':'
    auth = [Pusher.key, OpenSSL::HMAC.hexdigest(digest, Pusher.secret, to_sign)].join(':')

    websocket.send({
      event: 'pusher:subscribe',
      data: {
        auth: auth,
        channel_data: user_info.to_json,
        channel: 'presence-channel'
      }
    }.to_json)
  end

  def private_channel websocket, message
    socket_id = JSON.parse(message['data'])['socket_id']
    to_sign   = [socket_id, 'private-channel'].join ':'

    digest = OpenSSL::Digest::SHA256.new

    websocket.send({
      event: 'pusher:subscribe',
      data: {
        auth: [Pusher.key, OpenSSL::HMAC.hexdigest(digest, Pusher.secret, to_sign)].join(':'),
        channel: 'private-channel'
      }
    }.to_json)

  end
end
