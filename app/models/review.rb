class Review < ApplicationRecord
  belongs_to :pull_request
  has_many :agent_results, dependent: :destroy

  STATUSES = %w[pending reviewing done failed].freeze
  validates :status, inclusion: { in: STATUSES }
end
