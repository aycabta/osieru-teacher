require 'bundler'
require 'socket'
require 'optparse'
require './model'

params = ARGV.getopts('p:e:')

case params['e']
when 'production'
  DataMapper.setup(:default, ENV['DATABASE_URL'])
  database_upgrade!
when 'test', 'development', nil
  if ENV['DATABASE_URL']
    # 'postgres://aycabta@localhost:5432/osieru-teacher'
    DataMapper.setup(:default, ENV['DATABASE_URL'])
  else
    DataMapper.setup(:default, 'yaml:///tmp/osieru-teacher')
  end
  database_upgrade!
else
  DataMapper.setup(:default, 'yaml:///tmp/osieru-teacher')
  database_upgrade!
end

server = TCPServer.new(params['p'].to_i)
loop do
  body = 'osiete...'
  client = server.accept
  headers = []
  while header = client.gets
    break if header.chomp.empty?
    headers << header.chomp
  end
  p headers

  client.puts 'HTTP/1.0 200 OK'
  client.puts 'Content-Type: text/html;charset=utf-8'
  client.puts "Content-Length: #{body.bytesize}"
  client.puts
  client.puts body
  client.close
end
