class GeminiReviewJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(pr_data)
    Rails.logger.info "Starting Agentic AI review for PR ##{pr_data['pr_number']}"

    parsed_diff = DiffParser.parse(pr_data['diff'])
    Rails.logger.info "Parsed #{parsed_diff.keys.count} files for review"

    # Use the new agent orchestrator
    agentic_review = fetch_agentic_review(parsed_diff, pr_data)

    if agentic_review
      github_service = GithubService.new
      github_service.post_comment(
        owner: pr_data['owner'],
        repo: pr_data['repo'],
        pr_number: pr_data['pr_number'],
        comment: agentic_review
      )
      Rails.logger.info "Posted Agentic AI review to PR ##{pr_data['pr_number']}"
    else
      Rails.logger.warn "No review generated for PR ##{pr_data['pr_number']}"
    end
  rescue => e
    Rails.logger.error "Error in GeminiReviewJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def fetch_agentic_review(parsed_diff, pr_data)
    return nil unless ENV['GEMINI_API_KEY']

    orchestrator = AgentOrchestrator.new
    orchestrator.orchestrate_review(parsed_diff, pr_data)
  rescue ArgumentError => e
    Rails.logger.warn "Agent orchestrator error: #{e.message}"
    nil
  end

end
