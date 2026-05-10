class Setting < ApplicationRecord
  belongs_to :user

  def self.get(user, key)
    find_by(user: user, key: key)&.value
  end

  def self.set(user, key, value)
    find_or_initialize_by(user: user, key: key).tap { |s| s.update!(value: value) }
  end
end
