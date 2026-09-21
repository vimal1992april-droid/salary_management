require "test_helper"

class CountryTest < ActiveSupport::TestCase
  test "is valid with a name, ISO code and currency" do
    assert build(:country).valid?
  end

  test "requires a name" do
    assert_not build(:country, name: "").valid?
  end

  test "requires a two-letter uppercase ISO code" do
    %w[U USA us U1].each do |iso_code|
      assert_not build(:country, iso_code:).valid?, "#{iso_code.inspect} should be rejected"
    end
  end

  test "requires a unique ISO code" do
    create(:country, iso_code: "IN")

    assert_not build(:country, iso_code: "IN").valid?
  end

  test "requires a unique name" do
    create(:country, name: "India")

    assert_not build(:country, name: "india").valid?
  end

  test "requires a currency" do
    assert_not build(:country, currency: nil).valid?
  end

  test "exposes its currency code" do
    currency = create(:currency, code: "INR")

    assert_equal "INR", create(:country, currency:).currency_code
  end
end
