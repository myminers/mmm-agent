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

  def get(path)
    request_json :get, path
  end

  def post(path, params)
    request_json :post, path, params
  end

  private

  def request_json(method, path, params = {})
    response = request(method, path, params)
    body = JSON.parse(response.body)

    OpenStruct.new(:code => response.code, :body => body)
  rescue JSON::ParserError
    response
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
    
    #TODO retry until we get a response
    @http.request(request)
  end

end
