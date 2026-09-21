class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Authentication

  private

  # One error shape for the whole API: { "error": { "code", "message", "details"? } }
  def render_error(code, message, status:, details: nil)
    render json: { error: { code: code, message: message, details: details }.compact }, status: status
  end
end
