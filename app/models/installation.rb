class Installation < ApplicationRecord
  belongs_to :user
  has_many :pull_requests, dependent: :destroy

  before_validation :generate_webhook_secret, on: :create

  validates :owner, :repo, :webhook_secret, presence: true

  private

  def generate_webhook_secret
    self.webhook_secret = SecureRandom.hex(32)
  end
end
