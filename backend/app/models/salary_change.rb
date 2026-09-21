# One entry in an employee's salary history. Append-only: a mistake is corrected with a new change.
class SalaryChange < ApplicationRecord
  belongs_to :employee
  belongs_to :changed_by, class_name: "User", optional: true
  belongs_to :previous_currency, class_name: "Currency", foreign_key: :previous_currency_code, primary_key: :code
  belongs_to :new_currency, class_name: "Currency", foreign_key: :new_currency_code, primary_key: :code

  scope :newest_first, -> { order(effective_on: :desc, id: :desc) }

  validates :reason, presence: true, length: { maximum: 500 }
  validates :effective_on, presence: true
  validates :previous_amount, :new_amount,
            numericality: { greater_than: 0, less_than: Employee::MAX_SALARY }
  validate :differs_from_previous
  validate :effective_on_within_employment

  private

  def differs_from_previous
    return unless new_amount == previous_amount && new_currency_code == previous_currency_code

    errors.add(:new_amount, "must differ from the current salary")
  end

  # Scheduled (future-dated) raises are out of scope, so a change takes effect today at the latest.
  def effective_on_within_employment
    return unless effective_on

    errors.add(:effective_on, "cannot be in the future") if effective_on > Date.current
    errors.add(:effective_on, "cannot be before the hire date") if employee && effective_on < employee.hire_date
  end
end
