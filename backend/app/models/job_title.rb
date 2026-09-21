class JobTitle < ApplicationRecord
  has_many :employees, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :level, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
end
