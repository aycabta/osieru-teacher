require 'bundler'
require 'json'
require 'uri'
require 'net/https'
require './model'

case ENV['RACK_ENV']
when 'production'
  DataMapper.setup(:default, ENV['DATABASE_URL'])
  database_upgrade!
when 'test', 'development'
  DataMapper.setup(:default, 'yaml:///tmp/osieru-teacher')
  database_upgrade!
else
  DataMapper.setup(:default, 'yaml:///tmp/osieru-teacher')
  database_upgrade!
end

class InuDog
  def initialize
    ToriBird.create if ToriBird.all.size.zero?
    @tori_bird = ToriBird.first
    @commits = []
    @etag = @tori_bird.etag
    @new_etag = nil
    @latest_event_id = @tori_bird.event_id
    @new_latest_event_id = nil
  end

  def hand
    (1..10).each do |page|
      res = bow(page)
      break unless res
    end
    @tori_bird.update(etag: @new_etag) if @new_etag
    @tori_bird.update(event_id: @new_latest_event_id) if @new_latest_event_id
    @commits.reverse_each do |commit|
      whine(commit)
    end
  end

  def bow(page)
    puts "page #{page}"
    uri = URI.parse("https://api.github.com/repos/ruby/ruby/events?page=#{page}")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    res = nil
    https.start do
      req = Net::HTTP::Get.new(uri.request_uri)
      req['Authorization'] = "token #{@tori_bird.access_token}"
      req['If-None-Match'] = @etag
      res = https.request(req)
      case res.code
      when '200'
        if @new_etag.nil? and res['ETag'] != @tori_bird.etag
          @new_etag = res['ETag']
        end
      when '304' # Not Modified
        return nil
      else # unknown
        return nil
      end
      events = JSON.parse(res.body)
      events.each do |e|
        event_id = e['id'].to_i
        return nil if event_id == @latest_event_id
        @new_latest_event_id = event_id unless @new_latest_event_id
        if e['type'] == 'PushEvent'
          commits = e.fetch('payload')&.fetch('commits')
          commits.each(&method(:wow))
        end
      end
    end
    res
  end

  def wow(commit_overview)
    puts "commit: #{commit_overview['sha']}"
    sleep 2
    uri = URI.parse(commit_overview['url'])
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    https.start do
      req = Net::HTTP::Get.new(uri.request_uri)
      req['Authorization'] = "token #{@tori_bird.access_token}"
      res = https.request(req)
      commit = JSON.parse(res.body)
      commit['files'].each do |file|
        if file['filename'].include?('rdoc')
          puts "related commit found: #{commit_overview['sha']}"
          @commits << commit
          return
        end
      end
    end
  end

  def whine(commit)
    uri = URI.parse(ENV['SLACK_WEBHOOK_URL'])
    payload = {
      'text' =>
      "RDoc changes:\n" +
      "https://github.com/ruby/ruby/commit/#{commit['sha']}\n" +
      commit['files'].map{ |f| f['filename'] }.join("\n")
    }
    req = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
    req.body = payload.to_json
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    https.start do
      https.request(req)
    end
  end
end

InuDog.new.hand
