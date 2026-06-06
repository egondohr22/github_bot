class GeminiReviewJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(review_id)
    review = Review.find(review_id)
    pr = review.pull_request
    token = pr.installation.github_token
    pr_data = pr.as_context_hash.merge('comment' => review.triggered_by_comment)

    review.update!(status: 'reviewing')
    parsed_diff = DiffParser.parse(review.raw_diff)

    RepoCloner.with(owner: pr_data['owner'], repo: pr_data['repo'], ref: pr_data['head_branch'], token: token) do |cloner|
      final_comment = AgentOrchestrator.new.orchestrate_review(parsed_diff, pr_data, github_token: token, repo_cloner: cloner)

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
end
