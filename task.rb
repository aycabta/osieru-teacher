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

class InuDog
  def initialize
    ToriBird.create(etag: nil, event_id: nil, access_token: nil) if ToriBird.all.size.zero?
    @tori_bird = ToriBird.first
    @hits = []
    @etag = @tori_bird.etag
    @new_etag = nil
    @latest_event_id = @tori_bird.event_id
    @new_latest_event_id = nil
  end

  def hand
    # https://developer.github.com/v3/activity/events/
    (1..10).each do |page|
      res = bow(page)
      break unless res
    end
    @tori_bird.update(etag: @new_etag) if @new_etag
    @tori_bird.update(event_id: @new_latest_event_id) if @new_latest_event_id
    @hits.reverse_each do |hit|
      whine(hit)
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
          puts "new ETag: #{@new_etag}"
        end
      when '304' # Not Modified
        puts '304 Not Modified'
        return nil
      else # unknown
        return nil
      end
      events = JSON.parse(res.body)
      events.each do |e|
        event_id = e['id'].to_i
        if event_id == @latest_event_id
          puts 'reached latest event_id'
          return nil
        end
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
    # https://developer.github.com/v3/activity/events/types/#pushevent
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
      spree_digging(commit)
    end
  end

  def spree_digging(commit)
    EteMonkey.all.each do |em|
      if dig(commit, em)
        @hits << {
          em: em,
          commit: commit
        }
      end
    end
  end

  def dig(commit, em)
    em.bananas.each do |banana|
      commit['files'].each do |file|
        path = file['filename']
        if Regexp.new(banana.regexp_for_path).match?(path)
          puts "related commit found: #{commit['sha']} for #{em.gem_name}"
          return true
        end
      end
    end
    false
  end

  def whine(hit)
    # https://api.slack.com/incoming-webhooks
    commit = hit[:commit]
    em = hit[:em]
    puts "Say about #{commit['sha']} with #{em.gem_name}"
    uri = URI.parse(em.slack_webhook_url)
    payload = {
      'text' =>
      "#{em.gem_name} changes:\n" +
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
