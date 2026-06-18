class GeminiReviewJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(review_id)
    review = Review.find(review_id)
    pr = review.pull_request
    pr_data = pr.as_context_hash.merge('comment' => review.triggered_by_comment)
    token = GithubAppAuth.new.token_for(pr.installation)

    review.update!(status: 'reviewing')
    parsed_diff = DiffParser.parse(review.raw_diff)
    settings = pr.installation.user.review_settings

    RepoCloner.with(owner: pr_data['owner'], repo: pr_data['repo'], ref: pr_data['head_branch'], token: token) do |cloner|
      result = AgentOrchestrator.new(settings).orchestrate_review(parsed_diff, pr_data, token: token, repo_cloner: cloner)
      final_comment = result[:comment]
      persist_agent_results(review, result[:agent_results])

      GithubService.new(token: token).post_comment(
        owner: pr_data['owner'],
        repo: pr_data['repo'],
        pr_number: pr_data['pr_number'],
        comment: final_comment
      )

      review.update!(status: 'done', final_comment: final_comment, posted_at: Time.current)
      pr.update!(status: 'done')
    end
  rescue => e
    review&.update!(status: 'failed')
    raise
  end

  private

  def persist_agent_results(review, agent_results)
    review.agent_results.destroy_all
    Array(agent_results).each do |r|
      review.agent_results.create!(
        agent_name:      r[:agent],
        priority:        r[:priority],
        findings:        r[:findings],
        files_reviewed:  r[:files_reviewed] || [],
        tool_calls_made: r[:tool_calls] || 0
      )
    end
  end
end
