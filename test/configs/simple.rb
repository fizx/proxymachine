$logger = Logger.new(File.new('/tmp/proxymachine-server-test', 'w'))

callback = proc do |data|
  data + ":callback"
end

class TestServerConnection < EventMachine::Connection
  def self.request(host, port, callback)
    EventMachine.connect(host, port, self, callback)
  end

  def initialize(callback)
    @callback = callback
  end

  def receive_data(data)
    @callback.call(data)
  end
end

proxy do |data, conn|
  if data == 'a'
    { :remote => "localhost:9980" }
  elsif data == 'b'
    { :remote => "localhost:9981" }
  elsif data == 'c'
    { :remote => "localhost:9980", :data => 'ccc' }
  elsif data == 'd'
    { :close => 'ddd' }
  elsif data == 'e' * 2048
    { :noop => true }
  elsif data == 'e' * 2048 + 'f'
    { :remote => "localhost:9980" }
  elsif data == 'g'
    { :remote => "localhost:9980", :data => 'g2', :reply => 'g3-' }
  elsif data == 'h'
    { :remote => "localhost:9980", :callback => callback }
  elsif data == 'connect reject'
    { :remote => "localhost:9989" }
  elsif data == 'inactivity'
    { :remote => "localhost:9980", :data => 'sleep 3', :inactivity_timeout => 1, :inactivity_warning_timeout => 0.5 }
  elsif data == 'delayed'
    sc = TestServerConnection.request("localhost", 9981, proc{
      conn.establish_remote_server(:close => "ohai")
    })
    sc.send_data "delayed"
    { :noop => true }
  else
    { :close => true }
  end
end

ERROR_FILE = '/tmp/proxy_error'
WARN_FILE = '/tmp/proxy_warn'

proxy_connect_error do |remote, data, conn|
  msg = [remote, data].reject{|str|str.nil? || str.length == 0}.join(', ')
  File.open(ERROR_FILE, 'wb') { |fd| fd.write("connect error: #{msg}") }
end

proxy_inactivity_warning do |remote, data, conn|
  msg = [remote, data].reject{|str|str.nil? || str.length == 0}.join(', ')
  File.open(WARN_FILE, 'wb') { |fd| fd.write("activity warning: #{msg}") }
end

proxy_inactivity_error do |remote, data, conn|
  msg = [remote, data].reject{|str|str.nil? || str.length == 0}.join(', ')
  File.open(ERROR_FILE, 'wb') { |fd| fd.write("activity error: #{msg}") }
end
