class Session < ApplicationRecord
  EXPIRES_AFTER = 14.days

  belongs_to :user

  scope :active, -> { where(created_at: EXPIRES_AFTER.ago..) }

  def expired?
    created_at <= EXPIRES_AFTER.ago
  end
end
