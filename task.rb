require 'bundler'
require 'json'
require 'uri'
require 'net/https'
require './model'

class InuDog
  def bow
    uri = URI.parse('https://api.github.com/repos/ruby/ruby/events')
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    https.start do
      res = https.get(uri.path)
      events = JSON.parse(res.body)
      events.each do |e|
        if e['type'] == 'PushEvent'
          commits = e.fetch('payload')&.fetch('commits')
          commits.each(&method(:wow))
        end
      end
    end
  end

  def wow(commit_overview)
    uri = URI.parse(commit_overview['url'])
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    https.start do
      res = https.get(uri.path)
      commit = JSON.parse(res.body)
      commit['files'].each do |file|
        if file['filename'].include?('rdoc')
          whine(commit)
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

InuDog.new.bow
