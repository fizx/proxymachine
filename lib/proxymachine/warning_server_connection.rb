class ProxyMachine
  class WarningServerConnection < ServerConnection
    
    def initialize(conn)
      @warning_timeout = conn.inactivity_warning_timeout
      @warning_callback = conn.inactivity_warning_triggered
      super(conn)
    end
    
    def post_init
      if @warning_timeout
        @timer = EventMachine::Timer.new(@warning_timeout, &@warning_callback) 
      end
      super
    end
    
    def unbind
      @timer && @timer.cancel
      super
    end
  end
end
