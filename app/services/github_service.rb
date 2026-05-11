require 'base64'

class GithubService < ApplicationService
  API_BASE_URL = ENV['GITHUB_API_BASE_URL']

  def initialize(token:)
    @token = token
    @http = HttpService.new
  end

  def self.verify_signature!(raw_body, signature, secret)
    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, raw_body)}"
    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      raise SecurityError, "Invalid webhook signature"
    end
  end

  def list_repos
    response = with_retry { @http.get("#{API_BASE_URL}/user/repos?per_page=100&sort=updated", headers: auth_headers) }
    if response[:success]
      response[:body].map { |r| r['full_name'] }
    else
      log_error("Failed to list repos: #{response[:status]}")
      []
    end
  rescue HttpService::RequestError => e
    log_error("GitHub API request failed: #{e.message}")
    []
  end

  def post_comment(owner:, repo:, pr_number:, comment:)
    with_retry do
      @http.post(
        "#{API_BASE_URL}/repos/#{owner}/#{repo}/issues/#{pr_number}/comments",
        body: { body: comment },
        headers: auth_headers
      )
    end.then do |response|
      if response[:success]
        log_info("Posted comment to #{owner}/#{repo}##{pr_number}")
        response[:body]
      else
        log_error("Failed to post comment: #{response[:status]} - #{response[:raw_body]}")
        nil
      end
    end
  rescue HttpService::RequestError => e
    log_error("GitHub API request failed: #{e.message}")
    nil
  end

  def get_pull_request(owner:, repo:, pr_number:)
    response = with_retry { @http.get("#{API_BASE_URL}/repos/#{owner}/#{repo}/pulls/#{pr_number}", headers: auth_headers) }
    if response[:success]
      response[:body]
    else
      log_error("Failed to get PR: #{response[:status]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("GitHub API request failed: #{e.message}")
    nil
  end

  def get_file_content(owner:, repo:, path:, ref: 'HEAD')
    response = @http.get("#{API_BASE_URL}/repos/#{owner}/#{repo}/contents/#{path}?ref=#{ref}", headers: auth_headers)
    if response[:success]
      Base64.decode64(response[:body]['content']) if response[:body]['content']
    else
      log_error("Failed to get file #{path}: #{response[:status]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("GitHub API request failed: #{e.message}")
    nil
  end

  def search_code(owner:, repo:, query:)
    encoded  = URI.encode_www_form_component("#{query} repo:#{owner}/#{repo}")
    response = @http.get("#{API_BASE_URL}/search/code?q=#{encoded}", headers: auth_headers)
    if response[:success]
      (response[:body]['items'] || []).map { |item| { path: item['path'], name: item['name'] } }
    else
      log_error("Failed to search code: #{response[:status]}")
      []
    end
  rescue HttpService::RequestError => e
    log_error("GitHub search failed: #{e.message}")
    []
  end

  private

  def auth_headers
    {
      'Authorization' => "token #{@token}",
      'Accept'        => 'application/vnd.github.v3+json'
    }
  end

  def with_retry(retries: 3, &block)
    response = block.call
    if response[:status] == 429 && retries > 0
      wait = response.dig(:headers, 'retry-after', 0).to_i
      sleep(wait > 0 ? wait : 60)
      with_retry(retries: retries - 1, &block)
    else
      response
    end
  end
end
