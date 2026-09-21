class SalaryChangeSerializer
  def initialize(salary_change)
    @change = salary_change
  end

  def as_json(*)
    {
      id: @change.id,
      effective_on: @change.effective_on.iso8601,
      reason: @change.reason,
      previous_salary: { amount: @change.previous_amount.to_s("F"), currency: @change.previous_currency_code },
      new_salary: { amount: @change.new_amount.to_s("F"), currency: @change.new_currency_code },
      changed_by: @change.changed_by && UserSerializer.new(@change.changed_by),
      created_at: @change.created_at.iso8601(3)
    }
  end
end
