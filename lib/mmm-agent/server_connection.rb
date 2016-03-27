require "net/http"
require "uri"
require "ostruct"
require "json"

class MmmAgent::ServerConnection

  ENDPOINT = "https://www.multiminermanager.com"

  VERB_MAP = {
    :get    => Net::HTTP::Get,
    :post   => Net::HTTP::Post,
    :put    => Net::HTTP::Put,
    :delete => Net::HTTP::Delete
  }

  def initialize(options)
    @options = options
    uri = URI.parse(@options.server_url)
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = true unless @options.disable_ssl
  end

  def get(path, expected_code = '200')
    request_json :get, path, expected_code
  end

  def post(path, params, expected_code = '201')
    request_json :post, path, expected_code, params
  end

  private

  def request_json(method, path, expected_code, params = {})
    while true
      begin
        response = request(method, path, params)
        raise "Received HTTP response #{response.code} instead of #{expected_code} (#{path}, #{method})" if expected_code != response.code
        return JSON.parse(response.body)
      rescue StandardError => e
        Log.warning "Error contacting mmm-server: #{e.to_s}"
        Log.warning "Retrying in 60 seconds"
        sleep 60
      end
    end        
  end

  def request(method, path, params)
    case method
    when :get
      request = VERB_MAP[method.to_sym].new(path)
    when :post
      request = VERB_MAP[method.to_sym].new(path)
      request['Content-Type'] = 'application/json'
      request.body = params.to_json
    else
      request = VERB_MAP[method.to_sym].new(path)
    end
    request['X-User-Email'] = @options.email
    request['X-User-Token'] = @options.token
    
    @http.request(request)
  end

end
