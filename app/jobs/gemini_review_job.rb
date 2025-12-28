require_relative '../../lib/gemini_service'
require_relative '../../lib/github_service'

class GeminiReviewJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(pr_data)
    Rails.logger.info "Starting Gemini review for PR ##{pr_data['pr_number']}"

    parsed_diff = parse_diff(pr_data['diff'])
    Rails.logger.info "Parsed #{parsed_diff.keys.count} files for review"

    gemini_review = fetch_gemini_review(parsed_diff, pr_data['pr_number'])

    if gemini_review
      github_service = GitHubService.new
      github_service.post_comment(
        owner: pr_data['owner'],
        repo: pr_data['repo'],
        pr_number: pr_data['pr_number'],
        comment: format_review_comment(gemini_review)
      )
      Rails.logger.info "Posted Gemini review to PR ##{pr_data['pr_number']}"
    else
      Rails.logger.warn "No review generated for PR ##{pr_data['pr_number']}"
    end
  rescue => e
    Rails.logger.error "Error in GeminiReviewJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def fetch_gemini_review(parsed_diff, pr_number)
    return nil unless ENV['GEMINI_API_KEY']

    gemini = GeminiService.new
    gemini.code_review(parsed_diff, pr_number: pr_number)
  rescue ArgumentError => e
    Rails.logger.warn "Gemini service error: #{e.message}"
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

  def format_review_comment(review)
    "## AI Code Review\n\n#{review}"
  end
end
