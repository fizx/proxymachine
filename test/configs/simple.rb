LOGGER = Logger.new(File.new('/dev/null', 'w'))

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
  else
    { :close => true }
  end
end