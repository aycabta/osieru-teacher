require 'bundler'
require 'sinatra'
require './model'

configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
  database_upgrade!
end

configure :test, :development do
  DataMapper.setup(:default, 'yaml:///tmp/osieru-teacher')
  database_upgrade!
end

get '/' do
  'osiete...'
end
