# The API monitor is off in the test environment, so the many API tests do not each write a row. The tests of the
# monitor itself turn it on for the length of a block, with whatever limits they need.
module ApiMonitorHelper
  def with_monitor_settings(enabled: true, **settings)
    config = Rails.configuration.x.api_monitor
    original = config.to_h.slice(:enabled, :max_rows, :prune_every)
    config.enabled = enabled
    settings.each { |name, value| config.public_send("#{name}=", value) }
    yield
  ensure
    original.each { |name, value| config.public_send("#{name}=", value) }
  end
end

ActiveSupport::TestCase.include ApiMonitorHelper
