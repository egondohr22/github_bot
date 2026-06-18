class User < ApplicationRecord
  devise :database_authenticatable, :omniauthable, omniauth_providers: [:github]

  has_many :installations, dependent: :destroy
  has_many :settings, dependent: :destroy

  validates :uid, :github_username, :github_token, presence: true
  validates :email, presence: true, uniqueness: true

  def review_settings
    ReviewSettings.for(self)
  end

  def self.from_omniauth(auth)
    find_or_initialize_by(uid: auth.uid).tap do |user|
      user.email = auth.info.email
      user.github_username = auth.info.nickname
      user.name = auth.info.name
      user.github_token = auth.credentials.token
      user.save!
    end
  end
end
