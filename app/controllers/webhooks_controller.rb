class WebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  before_action :verify_signature!

  def github
    pr = find_or_create_pr(@installation, @payload)
    review = pr.reviews.create!(
      triggered_by_comment: @payload['comment'],
      raw_diff: @payload['diff'],
      status: 'pending'
    )

    GeminiReviewJob.perform_later(review.id)
    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue JSON::ParserError
    head :unprocessable_entity
  end

  private

  def verify_signature!
    @raw_body = request.body.read
    request.body.rewind

    @payload = JSON.parse(@raw_body)

    @installation = Installation.find_by(
      owner: @payload['owner'],
      repo:  @payload['repo']
    )
    return head :unauthorized unless @installation

    signature = request.headers['X-Hub-Signature-256'].to_s
    return head :unauthorized if signature.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', @installation.webhook_secret, @raw_body)}"
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  rescue JSON::ParserError
    head :unprocessable_entity
  end

  def find_or_create_pr(installation, payload)
    installation.pull_requests.find_or_create_by!(
      github_pr_number: payload['pr_number'].to_i,
      repo: payload['repo']
    ) do |pr|
      pr.head_branch = payload['head_branch']
      pr.base_branch = payload['base_branch']
      pr.author = payload['author']
      pr.status = 'pending'
    end
  end
end
