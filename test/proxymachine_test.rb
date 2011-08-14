require 'test_helper'

def assert_proxy(host, port, send, recv)
  sock = TCPSocket.new(host, port)
  sock.write(send)
  assert_equal recv, sock.read
  sock.close
end

class ProxymachineTest < Test::Unit::TestCase
  def setup
    @proxy_error_file = "#{File.dirname(__FILE__)}/proxy_error"
    puts "g"
    # require "ruby-debug"
    # debugger
  end

  def teardown
    File.unlink(@proxy_error_file) rescue nil
  end

  should "handle simple routing" do
    puts "h"
    assert_proxy('localhost', 9990, 'a', '9980:a')
    assert_proxy('localhost', 9990, 'b', '9981:b')
  end

  should "handle connection closing" do
    puts "hi1"
    sock = TCPSocket.new('localhost', 9990)
    sock.write('xxx')
    assert_equal nil, sock.read(1)
    sock.close
  end

  should "handle rewrite routing" do
    puts "hi2"
    assert_proxy('localhost', 9990, 'c', '9980:ccc')
  end

  should "handle rewrite closing" do
    puts "hi3"
        assert_proxy('localhost', 9990, 'd', 'ddd')
  end

  should "handle data plus reply" do
        puts "hi4"
    assert_proxy('localhost', 9990, 'g', 'g3-9980:g2')
  end

  should "handle noop" do
        puts "hi5"
    sock = TCPSocket.new('localhost', 9990)
    sock.write('e' * 2048)
    sock.flush
    sock.write('f')
    assert_equal '9980:' + 'e' * 2048 + 'f', sock.read
    sock.close
  end

  should "execute a callback" do
        puts "hi6"
    assert_proxy('localhost', 9990, 'h', '9980:h:callback')
  end
  
  # should "call proxy_connect_error when a connection is rejected" do
  #       puts "hi7"
  #   sock = TCPSocket.new('localhost', 9990)
  #   sock.write('connect reject')
  #   sock.flush
  #   assert_equal "", sock.read
  #   sock.close
  #   assert_equal "connect error: localhost:9989", File.read(@proxy_error_file)
  # end

  # should "call proxy_inactivity_error when initial read times out" do
  #       puts "hi8"
  #   sock = TCPSocket.new('localhost', 9990)
  #   sent = Time.now
  #   sock.write('inactivity')
  #   sock.flush
  #   assert_equal "", sock.read
  #   assert_operator Time.now - sent, :>=, 1.0
  #   assert_equal "activity error: localhost:9980", File.read(@proxy_error_file)
  #   sock.close
  # end

  should "not consider client disconnect a server error" do
        puts "hi9"
    sock = TCPSocket.new('localhost', 9990)
    sock.write('inactivity')
    sock.close
    sleep 3.1
    assert !File.exist?(@proxy_error_file)
  end
end
