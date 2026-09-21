module ApiMonitor
  # The endpoints the API offers, read from the router rather than kept in a list that could drift from it.
  module Endpoints
    Endpoint = Data.define(:http_method, :path, :controller, :action) do
      def label
        "#{http_method} #{path}"
      end
    end

    VERB_ORDER = %w[GET POST PATCH PUT DELETE].freeze
    FORMAT_SUFFIX = "(.:format)".freeze

    # Only what is under /api: not the pages, the admin panel or the catch-all that serves the React app. Rails
    # offers an update as both PATCH and PUT; it is listed once, as PATCH.
    def self.all
      endpoints = Rails.application.routes.routes.filter_map do |route|
        path = route.path.spec.to_s.delete_suffix(FORMAT_SUFFIX)
        next unless path.start_with?("/api/") && route.verb.present? && route.defaults[:controller]

        Endpoint.new(route.verb, path, route.defaults[:controller], route.defaults[:action])
      end

      endpoints = endpoints.reject { |endpoint| duplicate_put?(endpoint, endpoints) }
      endpoints.sort_by { |endpoint| [ endpoint.path, VERB_ORDER.index(endpoint.http_method) || VERB_ORDER.size ] }
    end

    def self.duplicate_put?(endpoint, endpoints)
      endpoint.http_method == "PUT" && endpoints.any? do |other|
        other.http_method == "PATCH" && other.path == endpoint.path && other.action == endpoint.action
      end
    end
    private_class_method :duplicate_put?
  end
end
