# Reads the directory's search parameters (filters, text search, sort, page) from the request, so the
# employee list and its CSV export always interpret them the same way.
module EmployeeSearchable
  extend ActiveSupport::Concern

  included do
    rescue_from Employees::Search::InvalidParameter do |error|
      render_error(:invalid_parameter, error.message, status: :bad_request)
    end
  end

  private

  def search_params
    params.permit(:q, :country_id, :department_id, :job_title_id, :status, :sort, :direction, :page, :per_page)
          .to_h.symbolize_keys
  end
end
