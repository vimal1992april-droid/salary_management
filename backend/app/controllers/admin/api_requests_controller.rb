module Admin
  # The recorded calls: a filtered, paged list, and one call in full with its payloads.
  class ApiRequestsController < BaseController
    FILTERS = %i[http_method status route q user_id min_duration].freeze

    def index
      @filters = params.slice(*FILTERS).permit(*FILTERS).to_h.symbolize_keys.compact_blank
      @result = ApiMonitor::Log.page(**@filters, page: params[:page], per_page: params[:per_page])
      @emails = User.where(id: @result.records.filter_map(&:user_id).uniq).pluck(:id, :email).to_h
      @routes = ApiMonitor::Endpoints.all.map(&:path).uniq
    end

    def show
      @call = ApiMonitor::Log.find(params[:id])
      @user = User.find_by(id: @call.user_id) if @call.user_id
    end
  end
end
