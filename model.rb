require 'bundler'
require 'dm-core'
require 'dm-migrations'

class ToriBird
  include DataMapper::Resource
  property :id, Serial
  property :etag, String, :length => 256, :required => false
  property :event_id, Decimal, :required => false
  property :access_token, String, :length => 256, :required => false
end

DataMapper.finalize

def database_upgrade!
  ToriBird.auto_upgrade!
end
