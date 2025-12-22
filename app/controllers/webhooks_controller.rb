require_relative '../../lib/gemini_service'

class WebhooksController < ApplicationController
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

    parsed_diff = parse_diff(diff)
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

  private

  def parse_diff(diff_text)
    result = {}
    current_file = nil
    before_lines = []
    after_lines = []
    in_hunk = false

    diff_text.each_line do |line|
      # Match file header (e.g., "diff --git a/file.rb b/file.rb")
      if line.start_with?('diff --git')
        # Save previous file if exists
        if current_file
          result[current_file] = {
            before: before_lines.join,
            after: after_lines.join
          }
        end

        # Extract filename (e.g., "a/Gemfile.lock" -> "Gemfile.lock")
        match = line.match(%r{diff --git a/(.*?) b/(.*)})
        current_file = match[2].strip if match
        before_lines = []
        after_lines = []
        in_hunk = false

      # Start of hunk (e.g., "@@ -386,7 +386,7 @@ GEM")
      elsif line.start_with?('@@')
        in_hunk = true

      # Lines in the diff
      elsif in_hunk
        if line.start_with?('-') && !line.start_with?('---')
          # Removed line (before)
          before_lines << line[1..-1]
        elsif line.start_with?('+') && !line.start_with?('+++')
          # Added line (after)
          after_lines << line[1..-1]
        elsif line.start_with?(' ')
          # Context line (appears in both)
          before_lines << line[1..-1]
          after_lines << line[1..-1]
        end
      end
    end

    # Save last file
    if current_file
      result[current_file] = {
        before: before_lines.join,
        after: after_lines.join
      }
    end

    result
  end
end
