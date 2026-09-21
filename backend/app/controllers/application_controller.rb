class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Authentication

  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error(:not_found, "#{error.model || 'Record'} not found", status: :not_found)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error(:validation_failed, "Validation failed", status: :unprocessable_entity,
                                                          details: error.record.errors.to_hash)
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_error(:bad_request, error.message, status: :bad_request)
  end

  private

  # One error shape for the whole API: { "error": { "code", "message", "details"? } }
  def render_error(code, message, status:, details: nil)
    render json: { error: { code: code, message: message, details: details }.compact }, status: status
  end
end
