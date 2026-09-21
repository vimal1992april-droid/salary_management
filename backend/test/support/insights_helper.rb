# Shortcuts for insight tests: one USD country, and a way to say "an employee paid 50,000 USD".
module InsightsHelper
  def usd
    @usd ||= create(:currency, code: "USD", name: "US Dollar", rate_to_usd: 1)
  end

  def us
    @us ||= create(:country, name: "United States", iso_code: "US", currency: usd)
  end

  # An active employee in the US paid `amount` USD; any attribute can be overridden.
  def paid(amount, **attributes)
    create(:employee, { country: us, salary_amount: amount }.merge(attributes))
  end
end
