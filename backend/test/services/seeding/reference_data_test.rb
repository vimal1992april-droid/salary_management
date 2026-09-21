require "test_helper"

class Seeding::ReferenceDataTest < ActiveSupport::TestCase
  test "creates every currency, country, department and job title in the catalog" do
    Seeding::ReferenceData.load!

    assert_equal Seeding::Catalog::CURRENCIES.size, Currency.count
    assert_equal Seeding::Catalog::COUNTRIES.size, Country.count
    assert_equal Seeding::Catalog::DEPARTMENTS.size, Department.count
    assert_equal Seeding::Catalog::DEPARTMENTS.sum { |department| department[:titles].size }, JobTitle.count
  end

  test "gives every currency a static USD rate and the date it applies from" do
    Seeding::ReferenceData.load!

    usd = Currency.find("USD")
    assert_equal 1, usd.rate_to_usd
    assert_equal Seeding::Catalog::RATES_AS_OF, usd.rate_as_of
    assert Currency.all.all? { |currency| currency.rate_to_usd.positive? }
  end

  test "pays every country in a currency from the catalog" do
    Seeding::ReferenceData.load!

    assert_equal "INR", Country.find_by!(iso_code: "IN").currency_code
    assert_equal "EUR", Country.find_by!(iso_code: "DE").currency_code
  end

  test "can run repeatedly without creating duplicates" do
    2.times { Seeding::ReferenceData.load! }

    assert_equal Seeding::Catalog::CURRENCIES.size, Currency.count
    assert_equal Seeding::Catalog::COUNTRIES.size, Country.count
    assert_equal Seeding::Catalog::DEPARTMENTS.size, Department.count
  end

  test "updates existing rows in place, restoring catalog values" do
    Seeding::ReferenceData.load!
    Currency.find("INR").update!(rate_to_usd: 999)

    Seeding::ReferenceData.load!

    assert_equal BigDecimal("0.012"), Currency.find("INR").rate_to_usd
  end
end
