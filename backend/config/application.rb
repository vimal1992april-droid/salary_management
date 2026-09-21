require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # The built React app that FrontendController serves (copied into public/ by the Docker build).
    config.x.frontend_index = config.root.join("public", "index.html")

    # By default the static file server answers "/" with public/index.html and a one-year cache header, bypassing
    # FrontendController's no-cache. That would leave browsers holding an old shell that names assets a later deploy
    # has removed. Pointing the directory index at a file that never exists sends "/" to the controller instead;
    # the hashed files under /assets/ are still served, and cached for a year, by the static file server.
    config.public_file_server.index_name = "index.disabled"

    # The API monitor records every call to /api for the admin panel. API_MONITOR=false turns it off; it keeps the
    # newest `max_rows` calls and trims the table every `prune_every` calls.
    config.x.api_monitor.enabled = ENV.fetch("API_MONITOR", "true") != "false"
    config.x.api_monitor.max_rows = 5_000
    config.x.api_monitor.prune_every = 50

    # API-only apps drop the cookie middleware; the HR session lives in a signed, httpOnly cookie.
    config.middleware.use ActionDispatch::Cookies
  end
end
