require_relative '../../lib/agent_orchestrator'
require_relative '../../lib/github_service'

class GeminiReviewJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(pr_data)
    Rails.logger.info "Starting Agentic AI review for PR ##{pr_data['pr_number']}"

    parsed_diff = parse_diff(pr_data['diff'])
    Rails.logger.info "Parsed #{parsed_diff.keys.count} files for review"

    # Use the new agent orchestrator
    agentic_review = fetch_agentic_review(parsed_diff, pr_data)

    if agentic_review
      github_service = GitHubService.new
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

  def parse_diff(diff_text)
    result = {}
    current_file = nil
    before_lines = []
    after_lines = []
    in_hunk = false

    diff_text.each_line do |line|
      if line.start_with?('diff --git')
        if current_file
          result[current_file] = {
            before: before_lines.join,
            after: after_lines.join
          }
        end

        match = line.match(%r{diff --git a/(.*?) b/(.*)})
        current_file = match[2].strip if match
        before_lines = []
        after_lines = []
        in_hunk = false

      elsif line.start_with?('@@')
        in_hunk = true

      elsif in_hunk
        if line.start_with?('-') && !line.start_with?('---')
          before_lines << line[1..-1]
        elsif line.start_with?('+') && !line.start_with?('+++')
          after_lines << line[1..-1]
        elsif line.start_with?(' ')
          before_lines << line[1..-1]
          after_lines << line[1..-1]
        end
      end
    end

    if current_file
      result[current_file] = {
        before: before_lines.join,
        after: after_lines.join
      }
    end

    result
  end

end
