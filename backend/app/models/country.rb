class Country < ApplicationRecord
  belongs_to :currency, foreign_key: :currency_code, primary_key: :code, inverse_of: :countries
  has_many :employees, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :iso_code, format: { with: /\A[A-Z]{2}\z/ }, uniqueness: true
end
