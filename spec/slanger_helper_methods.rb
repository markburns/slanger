module SlangerHelperMethods
  def start_slanger options={}, &blk
    # Fork service. Our integration tests MUST block the main thread because we
    # want to wait for i/o to finish.
    fork_reactor do |channel|
      options = default_slanger_options.merge(options)
      Slanger::Config.load options

      start_websocket_server! options
      start_api_server! options
      Slanger::Service.fetch_node_id!
      Slanger::Service.set_online_status!
      blk.call if blk
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
    {
      api_host:         '0.0.0.0',
      api_port:         '4567',
      websocket_host:   '0.0.0.0',
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
    Rack::Handler::Thin.run Slanger::Api::Server, api_server_options
  end

  def stop_slanger(pids=server_pids)
    pids.each do |pid|
      # Ensure Slanger is properly stopped. No orphaned processes allowed!
      Process.kill 'SIGKILL', pid rescue nil
      Process.wait pid rescue nil
    end
  end

  def wait_for_slanger opts = {}
    opts = default_slanger_options.merge opts
    wait_for_socket(opts[:api_port])
    wait_for_socket(opts[:websocket_port])
  end

  def wait_for_socket(port)
    retry_count = 100
    puts "Waiting for response on port #{port}..."
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

  def set_predictable_socket_and_subscription_ids!
    Slanger::Service.fetch_node_id!
    Slanger::Service.set_online_status!

    ids = (1..50).to_a.map{|i| "S#{Slanger.node_id}-#{i}"}
    allow(Slanger::Presence::Channel::RandomSubscriptionId).to receive(:next).
      and_return(*ids)

    ids = (1..50).to_a.map{|i| "#{Slanger.node_id}.#{i}"}
    allow(Slanger::Connection::RandomSocketId).to receive(:next).
      and_return(*ids)
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

  def em_stream opts = {}, messages=nil
    messages ||= []

    em_thread do
      websocket = new_websocket opts

      stream(websocket, messages) do |message|
        yield websocket, messages
      end
    end

    messages
  end

  def em_thread
    EM.run do

      unless (ENV["DEBUGGER"] || @timeout_timer_added)
        @timeout_timer_added = true

        EM.add_timer 3 do
          stop_slanger
          EM.stop

          raise Exception.new "Test timed out"
        end
      end

      yield


    end
  end

  def new_ws_stream messages, websocket_name=nil
    new_websocket.tap do |ws|
      stream ws, messages, websocket_name do |message|
        yield ws, message
      end
    end
  end

  def stream websocket, messages, websocket_name=nil
    websocket.stream do |message|
      Slanger.debug "SPEC #{websocket_name} message received #{message}\n"
      messages << JSON.parse(message)
      Slanger.debug "SPEC #{websocket_name} messages: [#{messages.join "\n"}]\n"

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
    auth = auth_from(socket_id, "presence-channel", user_info.to_json)

    websocket.send({
      event: 'pusher:subscribe',
      data: {
        auth: auth,
        channel_data: user_info.to_json,
        channel: 'presence-channel'
      }
    }.to_json)
  end

  def start_ha_proxy
    Slanger.debug "Starting haproxy"

    fork_reactor do
      exec "haproxy -f spec/support/haproxy.cfg"
    end
  end

  def stop_ha_proxy
    `killall -9 haproxy`
  end

  def start_slanger_nodes_and_haproxy(test_setup_1=nil, test_setup_2=nil)
    test_setup_1 ||= ->{ set_predictable_socket_and_subscription_ids!  }
    test_setup_2 ||= ->{ set_predictable_socket_and_subscription_ids!  }

    stop_ha_proxy
    start_slanger(websocket_port: 8081, api_port: 4568, &test_setup_1)
    start_slanger(websocket_port: 8082, api_port: 4569, &test_setup_2)
    wait_for_socket(8081)
    wait_for_socket(8082)

    start_ha_proxy
    wait_for_socket(8080)
    wait_for_socket(4567)
  end

  def em(time=0.01)
    EM.run do
      yield

      EM.add_timer time do
        EM.stop
      end
    end
  end

  def private_channel websocket, message, channel="channel"
    channel = "private-#{channel}"
    socket_id = JSON.parse(message['data'])['socket_id']

    auth = auth_from(socket_id, channel)

    websocket.send({
      event: 'pusher:subscribe',
      data: {
        auth: auth,
        channel: channel
      }
    }.to_json)
  end

  private

  def auth_from(socket_id, channel, channel_data=nil)
    to_sign   = [socket_id, channel, channel_data].compact.join ':'

    digest = OpenSSL::Digest::SHA256.new

    [Pusher.key, OpenSSL::HMAC.hexdigest(digest, Pusher.secret, to_sign)].join(':')
  end
end
