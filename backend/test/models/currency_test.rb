require "test_helper"

class CurrencyTest < ActiveSupport::TestCase
  test "is valid with a code, name, USD rate and rate date" do
    assert build(:currency).valid?
  end

  test "requires a three-letter uppercase code" do
    %w[US USDX usd U$D].each do |code|
      assert_not build(:currency, code:).valid?, "#{code.inspect} should be rejected"
    end
  end

  test "requires a unique code" do
    create(:currency, code: "EUR")

    duplicate = build(:currency, code: "EUR")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "requires a name" do
    assert_not build(:currency, name: "").valid?
  end

  test "requires a positive rate to USD" do
    [ nil, 0, -0.5 ].each do |rate|
      assert_not build(:currency, rate_to_usd: rate).valid?, "#{rate.inspect} should be rejected"
    end
  end

  test "requires the date the rate applies from" do
    assert_not build(:currency, rate_as_of: nil).valid?
  end
end
