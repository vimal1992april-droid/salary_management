class Employee < ApplicationRecord
  MAX_SALARY = 1_000_000_000_000 # decimal(14, 2) holds up to 12 whole digits

  belongs_to :country
  belongs_to :department
  belongs_to :job_title
  belongs_to :currency, foreign_key: :currency_code, primary_key: :code, inverse_of: :employees
  has_many :salary_changes, dependent: :restrict_with_error

  enum :status, { active: "active", inactive: "inactive" }, default: "active", validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  before_validation :default_currency_from_country, on: :create

  validates :employee_number, presence: true, uniqueness: true
  validates :first_name, :last_name, :hire_date, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :salary_amount, numericality: { greater_than: 0, less_than: MAX_SALARY }
  validate :hire_date_not_in_future

  def full_name
    "#{first_name} #{last_name}"
  end

  def salary_usd
    (salary_amount * currency.rate_to_usd).round(2)
  end

  private

  def default_currency_from_country
    self.currency = country&.currency if currency_code.blank?
  end

  def hire_date_not_in_future
    errors.add(:hire_date, "cannot be in the future") if hire_date && hire_date > Date.current
  end
end
