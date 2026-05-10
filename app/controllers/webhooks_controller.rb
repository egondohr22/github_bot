class WebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def github
    pr_number = params[:pr_number]
    base_branch = params[:base_branch]
    head_branch = params[:head_branch]
    comment = params[:comment]
    diff = params[:diff]
    owner = params[:owner]
    repo = params[:repo]

    Rails.logger.info "Received GitHub webhook: PR ##{pr_number}"
    Rails.logger.info "Repository: #{owner}/#{repo}"
    Rails.logger.info "Branches: #{base_branch}...#{head_branch}"
    Rails.logger.info "Comment: #{comment}"
    Rails.logger.info "Diff lines: #{diff&.lines&.count || 0}"

    parsed_diff = DiffParser.parse(diff)
    Rails.logger.info "Parsed #{parsed_diff.keys.count} files"

    pr_data = {
      'pr_number' => pr_number,
      'base_branch' => base_branch,
      'head_branch' => head_branch,
      'comment' => comment,
      'diff' => diff,
      'owner' => owner,
      'repo' => repo
    }

    GeminiReviewJob.perform_later(pr_data)
    Rails.logger.info "Enqueued GeminiReviewJob for PR ##{pr_number}"

    message = "I'm processing your request for PR ##{pr_number}.\n\n"
    message += "**Files changed:**\n"
    parsed_diff.keys.each do |file|
      message += "- `#{file}`\n"
    end
    message += "\n AI review will be posted shortly..."

    render json: { message: message }, status: :ok
  rescue => e
    Rails.logger.error "Error processing webhook: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

end
