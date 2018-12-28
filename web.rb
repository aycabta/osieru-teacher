require 'bundler'
require 'sinatra'
require './model'

configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
  database_upgrade!
end

configure :test, :development do
  if ENV['DATABASE_URL']
    DataMapper.setup(:default, ENV['DATABASE_URL'])
  else
    DataMapper.setup(:default, 'yaml:///tmp/osieru-teacher')
  end
  database_upgrade!
end

get '/' do
  'osiete...'
end
