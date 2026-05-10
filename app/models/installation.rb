class Installation < ApplicationRecord
  belongs_to :user
  has_many :pull_requests, dependent: :destroy

  validates :owner, :repo, :webhook_secret, presence: true

  delegate :github_token, to: :user
end
