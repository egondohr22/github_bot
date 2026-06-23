require "jwt"
require "openssl"

class GithubAppAuth
  API_BASE_URL = ENV['GITHUB_API_BASE_URL']

  TOKEN_PERMISSIONS = { "contents" => "read", "pull_requests" => "write" }.freeze

  TOKEN_TTL = 50.minutes

  class Error < StandardError; end
  class StaleInstallationError < Error; end

  def initialize
    @http = HttpService.new
  end

  def token_for(installation)
    installation_id = installation.github_installation_id || resolve_installation_id(installation)
    cached_token(installation_id, repo_name(installation))
  rescue StaleInstallationError
    installation_id = resolve_installation_id(installation)
    cached_token(installation_id, repo_name(installation))
  end

  private

  def cached_token(installation_id, repo)
    Rails.cache.fetch("github_app/token/#{installation_id}/#{repo}", expires_in: TOKEN_TTL) do
      request_installation_token(installation_id, repo)
    end
  end

  def resolve_installation_id(installation)
    owner = installation.owner
    repo  = repo_name(installation)
    response = @http.get("#{API_BASE_URL}/repos/#{owner}/#{repo}/installation", headers: app_headers)
    unless response[:success]
      raise Error, "No GitHub App installation for #{owner}/#{repo} (HTTP #{response[:status]})"
    end

    id = response[:body].fetch("id")
    installation.update!(github_installation_id: id)
    id
  end

  def repo_name(installation)
    installation.repo.to_s.split("/").last
  end

  def request_installation_token(installation_id, repo)
    response = @http.post(
      "#{API_BASE_URL}/app/installations/#{installation_id}/access_tokens",
      body: { repositories: [repo], permissions: TOKEN_PERMISSIONS },
      headers: app_headers
    )
    raise StaleInstallationError if response[:status] == 404
    unless response[:success]
      raise Error, "Could not get installation token for #{repo} (HTTP #{response[:status]})"
    end

    response[:body].fetch("token")
  end

  def app_headers
    {
      "Authorization" => "Bearer #{app_jwt}",
      "Accept" => "application/vnd.github+json"
    }
  end

  def app_jwt
    now = Time.now.to_i
    payload = {
      iat: now - 60,
      exp: now + (9 * 60),
      iss: ENV.fetch("GITHUB_APP_ID")
    }
    JWT.encode(payload, app_private_key, "RS256")
  end

  def app_private_key
    @app_private_key ||= OpenSSL::PKey::RSA.new(File.read(ENV.fetch("GITHUB_APP_PRIVATE_KEY_PATH")))
  end
end
