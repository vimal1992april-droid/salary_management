require "test_helper"

class ApiMonitor::LiveCheckTest < ActiveSupport::TestCase
  test "reports the database as up, and how long it took to answer" do
    check = ApiMonitor::LiveCheck.call

    assert check.database_up
    assert_kind_of Numeric, check.database_ms
    assert_operator check.database_ms, :>=, 0
  end

  test "reports the database as down when it does not answer, instead of failing" do
    connection = ActiveRecord::Base.connection

    replace_method(connection, :select_value, ->(*) { raise ActiveRecord::ConnectionNotEstablished, "gone" }) do
      check = ApiMonitor::LiveCheck.call

      assert_not check.database_up
      assert_nil check.database_ms
    end
  end

  test "says whether calls are being recorded, and how many are kept" do
    create_list(:api_request, 2)

    with_monitor_settings(enabled: true, max_rows: 700) do
      check = ApiMonitor::LiveCheck.call

      assert check.recording
      assert_equal 2, check.stored_calls
      assert_equal 700, check.max_rows
    end
    with_monitor_settings(enabled: false) { assert_not ApiMonitor::LiveCheck.call.recording }
  end

  test "names the environment and the Rails version" do
    check = ApiMonitor::LiveCheck.call

    assert_equal Rails.env, check.environment
    assert_equal Rails.version, check.rails_version
  end
end
