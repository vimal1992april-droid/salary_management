module Admin
  # Which of the API's endpoints exist, how each has been doing over the last day, and whether the system is up.
  class ApiMonitorController < BaseController
    def show
      @live = ApiMonitor::LiveCheck.call
      @stats = ApiMonitor::Stats.call
    end
  end
end
