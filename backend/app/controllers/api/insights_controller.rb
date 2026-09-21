module Api
  # Read-only answers to "how does the organisation pay its people?". Money is returned as strings.
  class InsightsController < ApplicationController
    rescue_from Insights::InvalidParameter do |error|
      render_error(:invalid_parameter, error.message, status: :bad_request)
    end

    def overview
      render json: { data: Insights::Overview.call }
    end

    def salary_stats
      render json: { data: Insights::SalaryStats.call(group_by: params[:group_by], **filters) }
    end

    def distribution
      render json: { data: Insights::Distribution.call(bucket_count: params[:bucket_count], **filters) }
    end

    def top_earners
      employees = Insights::TopEarners.call(direction: params[:direction], limit: params[:limit])

      render json: { data: employees.map { |employee| EmployeeSerializer.new(employee) } }
    end

    private

    def filters
      params.permit(:country_id, :department_id, :job_title_id).to_h.symbolize_keys
    end
  end
end
