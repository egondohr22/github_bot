class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:github]

  has_many :installations, dependent: :destroy
  has_many :settings, dependent: :destroy

  validates :uid, :github_username, :github_token, presence: true

  def self.from_omniauth(auth)
    find_or_initialize_by(uid: auth.uid).tap do |user|
      user.email           = auth.info.email
      user.github_username = auth.info.nickname
      user.name = auth.info.name
      user.github_token = auth.credentials.token
      user.password = Devise.friendly_token[0, 20] if user.new_record?
      user.save!
    end
  end
end
