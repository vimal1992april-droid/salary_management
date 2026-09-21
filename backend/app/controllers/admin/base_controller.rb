module Admin
  # Base of the server-rendered admin panel. Independent of the JSON API's controllers and of its session: the
  # administrator's identity lives in a Rails session cookie, and every page requires it.
  class BaseController < ActionController::Base
    SESSION_LIFETIME = 8.hours

    protect_from_forgery with: :exception
    layout "admin"

    helper AdminHelper, AdminChartHelper, AdminAssetsHelper, AdminIconHelper, AdminNavHelper

    before_action :require_admin
    helper_method :current_admin

    rescue_from ActiveRecord::RecordNotFound do |error|
      @message = error.message
      render "admin/shared/not_found", status: :not_found
    end

    private

    def current_admin
      return @current_admin if defined?(@current_admin)

      @current_admin = admin_from_session
    end

    def require_admin
      redirect_to admin_login_path unless current_admin
    end

    # The role is checked on every request, so taking it away ends access at once. The cookie's own expiry is only a
    # browser-side courtesy; the age is checked here too, so a copied cookie does not outlive the session.
    def admin_from_session
      signed_in_at = session[:admin_signed_in_at]
      return unless session[:admin_id] && signed_in_at && Time.zone.at(signed_in_at) > SESSION_LIFETIME.ago

      User.admins.find_by(id: session[:admin_id])
    end

    def start_admin_session(user)
      reset_session # never keep a session id from before signing in
      session[:admin_id] = user.id
      session[:admin_signed_in_at] = Time.current.to_i
      @current_admin = user
    end

    def end_admin_session
      reset_session
      @current_admin = nil
    end
  end
end
