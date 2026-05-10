class PullRequest < ApplicationRecord
  belongs_to :installation
  has_many :reviews, dependent: :destroy

  STATUSES = %w[pending reviewing done failed].freeze
  validates :status, inclusion: { in: STATUSES }

  def as_context_hash
    owner, repo_name = repo.split("/", 2)
    {
      "pr_number"   => github_pr_number,
      "owner"       => owner,
      "repo"        => repo_name,
      "head_branch" => head_branch,
      "base_branch" => base_branch
    }
  end
end
