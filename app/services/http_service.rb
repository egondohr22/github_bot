require 'net/http'
require 'json'

class HttpService
  class RequestError < StandardError; end

  def initialize(read_timeout: 30, open_timeout: 10)
    @default_headers = { 'Content-Type' => 'application/json' }
    @read_timeout = read_timeout
    @open_timeout = open_timeout
  end

  def get(url, headers: {})
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    apply_headers(request, headers)
    execute_request(build_http(uri), request)
  end

  def post(url, body: {}, headers: {})
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    apply_headers(request, headers)
    request.body = body.is_a?(String) ? body : body.to_json
    execute_request(build_http(uri), request)
  end

  def put(url, body: {}, headers: {})
    uri = URI(url)
    request = Net::HTTP::Put.new(uri)
    apply_headers(request, headers)
    request.body = body.is_a?(String) ? body : body.to_json
    execute_request(build_http(uri), request)
  end

  def delete(url, headers: {})
    uri = URI(url)
    request = Net::HTTP::Delete.new(uri)
    apply_headers(request, headers)
    execute_request(build_http(uri), request)
  end

  private

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = @read_timeout
    http.open_timeout = @open_timeout
    http
  end

  def apply_headers(request, custom_headers)
    @default_headers.merge(custom_headers).each { |k, v| request[k] = v }
  end

  def execute_request(http, request)
    response = http.request(request)
    {
      success: response.is_a?(Net::HTTPSuccess),
      status: response.code.to_i,
      body: parse_response_body(response),
      raw_body: response.body,
      headers:  response.to_hash
    }
  rescue => e
    Rails.logger.error "HTTP request failed: #{e.message}"
    raise RequestError, "Request failed: #{e.message}"
  end

  def parse_response_body(response)
    return nil if response.body.nil? || response.body.empty?
    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body
  end
end
