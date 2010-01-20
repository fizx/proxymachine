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
      if returned = @callback.call(@buffer.join(''))
        proxy_incoming_to(@client_side, 10240)
        @client_side.send_data returned
      end
    rescue => e
      $logger.info e.message + e.backtrace.join("\n")
    end

    def unbind
      @client_side.close_connection_after_writing
    end
  end
end
