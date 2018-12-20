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

class EteMonkey
  include DataMapper::Resource
  property :id, Serial
  has n, :bananas
  property :gem_name, String, :length => 256, :required => true
  property :slack_webhook_url, String, :length => 256, :required => true
end

class Banana
  include DataMapper::Resource
  property :id, Serial
  belongs_to :ete_monkey
  property :regexp_for_path, Text, :required => true
end

DataMapper.finalize

def database_upgrade!
  ToriBird.auto_upgrade!
  EteMonkey.auto_upgrade!
  Banana.auto_upgrade!
end
