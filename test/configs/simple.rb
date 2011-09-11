$logger = Logger.new(File.new('/tmp/proxymachine-server-test', 'w'))

callback = proc do |data|
  data + ":callback"
end

proxy do |data|
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
  else
    { :close => true }
  end
end

ERROR_FILE = '/tmp/proxy_error'
WARN_FILE = '/tmp/proxy_warn'

proxy_connect_error do |remote|
  File.open(ERROR_FILE, 'wb') { |fd| fd.write("connect error: #{remote}") }
end

proxy_inactivity_warning do |remote|
  File.open(WARN_FILE, 'wb') { |fd| fd.write("activity warning: #{remote}") }
end

proxy_inactivity_error do |remote|
  File.open(ERROR_FILE, 'wb') { |fd| fd.write("activity error: #{remote}") }
end
