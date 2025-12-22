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

    headers = {
      'Authorization' => "token #{@token}",
      'Accept' => 'application/vnd.github.v3+json'
    }

    body = { body: comment }

    response = @http_service.post(url, body: body, headers: headers)

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

    headers = {
      'Authorization' => "token #{@token}",
      'Accept' => 'application/vnd.github.v3+json'
    }

    response = @http_service.get(url, headers: headers)

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

  private

  def validate_token!
    unless @token
      raise ArgumentError, "GITHUB_TOKEN environment variable is not set"
    end
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
