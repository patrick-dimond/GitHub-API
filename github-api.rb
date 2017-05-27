require 'net/http'
require 'time'

class GitHubAPI

  attr_reader :etag, :last_request, :poll_interval, :rate_limit, :rate_limit_remaining, 
    :rate_limit_reset, :body
  attr_accessor :endpoint

  def initialize(endpoint, options = {})
    
    @base = "https://api.github.com"
    @poll_interval = 0
    @last_request = Time.now
    @rate_limit = 100
    @rate_limit_remaining = 100
    @rate_limit_reset = Time.now
    @body = nil

  end

  def polite_get() 

    if !rate_limit_check()
      return 
    end

    if !interval_check()
      return
    end

    get()

  end

  def impatient_get()

    if !rate_limit_check()
      return 
    end

    get()

  end

  def interval_check()

   if @last_request + @poll_interval > Time.now
     puts "You must wait #{@last_request + @poll_interval - Time.now} seconds"
     return false
   end
   return true

  end

  def rate_limit_check()

    if @rate_limit_remaining <= 0
      puts "Rate limit exhausted. Resets at #{@rate_limit_reset.asctime}"
      return false
    end
    return true

  end


  def get()

    req = Net::HTTP::Get.new(@endpoint)
    req['If-None-Match'] = @etag unless @etag.nil?

    use_ssl = @endpoint.scheme == "https" ? true : false


    Net::HTTP.start(endpoint.host, endpoint.port, :use_ssl => use_ssl) do |http|
      
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

      puts "#{@rate_limit_remaining}/#{@rate_limit} requests remaining"
      puts "Limit resets at #{@rate_limit_reset.asctime}" 

    end

  end


  private 
  def save_headers(res)

    @etag = res['ETag']
    @poll_interval = res['X-Poll-Interval'].to_i
    @rate_limit = res['X-RateLimit-Limit'].to_i
    @rate_limit_remaining = res['X-RateLimit-Remaining'].to_i
    @rate_limit_reset = Time.at(res['X-RateLimit-Reset'].to_i)

  end

end


class Endpoint

  attr_reader :etag
  attr_accessor :uri

  def initialise

    @etag
    @uri

  end



end
