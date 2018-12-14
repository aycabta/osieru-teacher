require 'bundler'
require 'dm-core'
require 'dm-migrations'

class ToriBird
  include DataMapper::Resource
  property :id, Serial
  property :etag, String, :length => 256, :required => false
  property :push_event_id, Integer, :required => true
end

DataMapper.finalize

def database_upgrade!
  ToriBird.auto_upgrade!
end
