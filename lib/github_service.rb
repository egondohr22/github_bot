require 'base64'
require_relative 'http_service'

class GitHubService
  API_BASE_URL = 'https://api.github.com'

  def initialize(token: nil)
    @token = token || ENV['GITHUB_TOKEN']
    @http_service = HttpService.new
    validate_token!
  end

  def post_comment(owner:, repo:, pr_number:, comment:)
    url = "#{API_BASE_URL}/repos/#{owner}/#{repo}/issues/#{pr_number}/comments"
    response = @http_service.post(url, body: { body: comment }, headers: auth_headers)

    if response[:success]
      log_info("Successfully posted comment to #{owner}/#{repo}##{pr_number}")
      response[:body]
    else
      log_error("Failed to post comment: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("GitHub API request failed: #{e.message}")
    nil
  end

  def get_pull_request(owner:, repo:, pr_number:)
    url = "#{API_BASE_URL}/repos/#{owner}/#{repo}/pulls/#{pr_number}"
    response = @http_service.get(url, headers: auth_headers)

    if response[:success]
      response[:body]
    else
      log_error("Failed to get PR: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("GitHub API request failed: #{e.message}")
    nil
  end

  def get_file_content(owner:, repo:, path:, ref: 'HEAD')
    url = "#{API_BASE_URL}/repos/#{owner}/#{repo}/contents/#{path}?ref=#{ref}"
    response = @http_service.get(url, headers: auth_headers)

    if response[:success]
      content = response[:body]
      Base64.decode64(content['content']) if content['content']
    else
      log_error("Failed to get file #{path}: #{response[:status]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("GitHub API request failed: #{e.message}")
    nil
  end

  def search_code(owner:, repo:, query:)
    encoded_query = URI.encode_www_form_component("#{query} repo:#{owner}/#{repo}")
    url = "#{API_BASE_URL}/search/code?q=#{encoded_query}"
    response = @http_service.get(url, headers: auth_headers)
    binding.pry
    if response[:success]
      items = response[:body]['items'] || []
      items.map { |item| { path: item['path'], name: item['name'] } }
    else
      log_error("Failed to search code: #{response[:status]}")
      []
    end
  rescue HttpService::RequestError => e
    log_error("GitHub search failed: #{e.message}")
    []
  end

  private

  def validate_token!
    unless @token
      raise ArgumentError, "GITHUB_TOKEN environment variable is not set"
    end
  end

  def auth_headers
    {
      'Authorization' => "token #{@token}",
      'Accept' => 'application/vnd.github.v3+json'
    }
  end

  def log_info(message)
    if defined?(Rails)
      Rails.logger.info message
    else
      puts "[INFO] #{message}"
    end
  end

  def log_error(message)
    if defined?(Rails)
      Rails.logger.error message
    else
      puts "[ERROR] #{message}"
    end
  end
end
