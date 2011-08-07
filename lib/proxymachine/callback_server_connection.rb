class ProxyMachine
  class CallbackServerConnection < ServerConnection
    
    def post_init
      # empty
    end
    
    def callback=(c)
      @callback = c
    end
    
    def receive_data(data)
      @buffer ||= []
      @buffer << data
      @data_received = true
      if returned = @callback.call(@buffer.join(''))
        @client_side.send_data returned
        proxy_incoming_to(@client_side, 10240)
      end
    rescue => e
      $logger.info e.message + e.backtrace.join("\n")
    end
  end
end
