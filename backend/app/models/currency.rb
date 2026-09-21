class Currency < ApplicationRecord
  self.primary_key = :code

  has_many :countries, foreign_key: :currency_code, primary_key: :code, inverse_of: :currency,
                       dependent: :restrict_with_error

  validates :code, format: { with: /\A[A-Z]{3}\z/ }, uniqueness: true
  validates :name, presence: true
  validates :rate_to_usd, numericality: { greater_than: 0 }
  validates :rate_as_of, presence: true
end
