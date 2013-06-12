class ProxyMachine
  class ClientConnection < EventMachine::Connection
    def self.start(host, port)
      $server = EM.start_server(host, port, self)
      $logger.info "Listening on #{host}:#{port}"
      $logger.info "Send QUIT to quit after waiting for all connections to finish."
      $logger.info "Send TERM or INT to quit after waiting for up to 10 seconds for connections to finish."
    end

    def post_init
      $logger.info "Accepted #{peer}"
      @buffer = []
      @remote = nil
      @tries = 0
      @connected = false
      @connect_timeout = nil
      @inactivity_timeout = nil
      ProxyMachine.incr(self)
    end

    def peer
      @peer ||=
      begin
        port, ip = Socket.unpack_sockaddr_in(get_peername)
        "#{ip}:#{port}"
      end
    end

    def receive_data(data)
      if !@connected
        @buffer << data
        establish_remote_server if @remote.nil?
      end
    rescue => e
      close_connection
      $logger.error "#{e.class} - #{e.message}"
    end

    # Called when new data is available from the client but no remote
    # server has been established. If a remote can be established, an
    # attempt is made to connect and proxy to the remote server.
    def establish_remote_server(routes = nil)
      fail "establish_remote_server called with remote established" if @remote
      @routes = [routes || ProxyMachine.router.call(@buffer.join, self) || {}].flatten
      try_connect
    end

    attr_reader :inactivity_warning_timeout, :inactivity_warning_callback

    def try_connect
      @commands = @routes.shift
      $logger.info "#{peer} #{@commands.inspect}"
      close_connection unless @commands.instance_of?(Hash)
      if remote = @commands[:remote]
        m, host, port = *remote.match(/^(.+):(.+)$/)
        @remote = [host, port]
        if data = @commands[:data]
          @buffer = [data]
        end
        if reply = @commands[:reply]
          send_data(reply)
        end
        @connect_timeout = @commands[:connect_timeout]
        @inactivity_timeout = @commands[:inactivity_timeout]
        @inactivity_warning_timeout = @commands[:inactivity_warning_timeout]
        @connect_error_callback = @commands[:connect_error_callback]
        @inactivity_error_callback = @commands[:inactivity_error_callback]
        @inactivity_warning_callback = @commands[:inactivity_warning_callback]
        connect_to_server
      elsif close = @commands[:close]
        if close == true
          close_connection
        else
          send_data(close)
          close_connection_after_writing
        end
      elsif @commands[:noop]
        # do nothing
      else
        close_connection
      end
    end

    # Connect to the remote server
    def connect_to_server
      fail "connect_server called without remote established" if @remote.nil?
      host, port = @remote
      $logger.info "Establishing new connection with #{host}:#{port}"
      cb = @commands[:callback]
      klass = cb ? CallbackServerConnection : WarningServerConnection
      @server_side = klass.request(host, port, self)
      @server_side.callback = cb if cb
      @server_side.pending_connect_timeout = @connect_timeout
      @server_side.comm_inactivity_timeout = @inactivity_timeout
    end

    # Called by the server side immediately after the server connection was
    # successfully established. Send any buffer we've accumulated and start
    # raw proxying.
    def server_connection_success
      $logger.info "Successful connection to #{@remote.join(':')}"
      @connected = true
      @buffer.each { |data| @server_side.send_data(data) }
      @buffer = []
      proxy_incoming_to(@server_side, 10240)
    end

    def inactivity_warning_triggered
      proc {
        (@inactivity_warning_callback || ProxyMachine.inactivity_warning_callback).call(@remote.join(':'), @buffer.join, self)
      }
    end

    # Called by the server side when a connection could not be established,
    # either due to a hard connection failure or to a connection timeout.
    # Leave the client connection open and retry the server connection up to
    # 10 times.
    def server_connection_failed
      @server_side = nil
      if @connected
        $logger.error "Connection with #{@remote.join(':')} was terminated prematurely."
        close_connection
        (@connect_error_callback || ProxyMachine.connect_error_callback).call(@remote.join(':'), @buffer.join, self)
      elsif @routes.size > 0
        @tries += 1
        $logger.warn "Retrying connection with #{@remote.join(':')} (##{@tries})"
        EM.add_timer(0.1) { try_connect }
      else
        $logger.error "Connect #{@remote.join(':')} failed after exhausting failovers."
        close_connection
        (@connect_error_callback || ProxyMachine.connect_error_callback).call(@remote.join(':'), @buffer.join, self)
      end
    end

    # Called by the server when an inactivity timeout is detected. The timeout
    # argument is the configured inactivity timeout in seconds as a float; the
    # elapsed argument is the amount of time that actually elapsed since
    # connecting but not receiving any data.
    def server_inactivity_timeout(timeout, elapsed)
      $logger.error "Disconnecting #{@remote.join(':')} after #{elapsed}s of inactivity (> #{timeout.inspect})"
      @server_side = nil
      close_connection
      (@inactivity_error_callback || ProxyMachine.inactivity_error_callback).call(@remote.join(':'), @buffer.join, self)
    end

    def unbind
      @server_side.close_connection_after_writing if @server_side
      ProxyMachine.decr(self)
    end

    # Proxy connection has been lost
    def proxy_target_unbound
      @server_side = nil
    end
  end
end
