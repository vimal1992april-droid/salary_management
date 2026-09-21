# The API monitor records every call to the JSON API so an administrator can see what is being asked and answered.
# Payloads can hold secrets and people's pay, so the rules for what is kept live in one place (Redactor), and the
# whole thing can be switched off with API_MONITOR=false.
module ApiMonitor
  # Where the API's controllers leave the id of the signed-in user for the middleware, which runs outside them.
  USER_ENV_KEY = "api_monitor.user_id".freeze

  module_function

  def settings
    Rails.configuration.x.api_monitor
  end

  # `config.x` answers an undefined setting with an empty (truthy) options object, so only a real `true` counts.
  def enabled?
    settings.enabled == true
  end
end
