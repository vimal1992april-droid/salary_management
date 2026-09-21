class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :salary_changes, foreign_key: :changed_by_id, inverse_of: :changed_by, dependent: :nullify

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
end
