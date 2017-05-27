require 'net/http'
require 'time'

class RateLimitExceededError < StandardError
  attr_reader :reset_time
  def initialize(msg="Rate limit exceeded", reset_time)
    @reset_time = reset
    super
  end
end

class GitHubAPI

  attr_reader :poll_interval, :rate_limit, :rate_limit_remaining, 
    :rate_limit_reset, :base
  attr_accessor :endpoints

  def initialize(options = {})
    
    @base = "https://api.github.com"
    @poll_interval = 0
    @rate_limit = 100
    @rate_limit_remaining = 100
    @rate_limit_reset = Time.now
    @endpoints = init_endpoints(options[:endpoints])
    @user_agent = options[:user_agent] || ''
    @auth_token = options[:auth_token] || ''

  end

  def init_endpoints(endpoints)
    return endpoints.map { |endpoint| Endpoint.new(@base + endpoint) }
  end
  
  def limit_exceeded()
    return @rate_limit_reamaining <= 0 ? false : true
  end


  def get(endpoint)

    raise RateLimitExceededError("Rate limit exceeded", @rate_limit_reset) if limit_exceeded

    req = Net::HTTP::Get.new(endpoint.uri)
    generate_headers(req, endpoint)

    Net::HTTP.start(endpoint.uri.host, endpoint.uri.port, :use_ssl => true) do |http|
      
      res = http.request(req)
      @last_request = Time.now

      case res
      when Net::HTTPSuccess then
        save_headers(res)
      when Net::HTTPNotModified then
        puts "Nothing new"
        return
      else
        puts res.value
        return
      end

      @body = res.body

      update_state(res, endpoint)

    end

  end

  def generate_headers(req, endpoint)
    req['User-Agent'] = @user_agent unless @user_agent.empty?
    req['Authorization'] = "token " + @auth_token unless @auth_token.empty?

    endpoint.generate_headers(req)
  end

  private 
  def update_state(res)
    @poll_interval = res['X-Poll-Interval'].to_i
    @rate_limit = res['X-RateLimit-Limit'].to_i
    @rate_limit_remaining = res['X-RateLimit-Remaining'].to_i
    @rate_limit_reset = Time.at(res['X-RateLimit-Reset'].to_i)

    endpoint.update_state(res)
  end

end


class Endpoint

  attr_reader :etag, :body, :last_request
  attr_accessor :uri

  def initialise(endpoint, options = {})
    @etag = ''
    @uri = URI(endpoint)
    @last_request = Time.now
    @body = ''
  end

  def generate_headers(req)
    req["ETag"] = @etag unless @etag.empty?
  end

  def update_state(res)
    @etag = res['ETag']
    @last_request = Time.now
    @body = res.body
  end

  def interval_complete(poll_interval)
    return @last_request + poll_interval > Time.now ? false : true
  end

  def to_s
    @uri
  end

end
