module Admin
  class DashboardController < BaseController
    def show
      @metrics = Admin::Metrics.call
    end
  end
end
