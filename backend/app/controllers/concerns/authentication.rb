# Cookie-session authentication for the API. Every action requires a signed-in user unless it opts
# out with `allow_unauthenticated_access`.
#
# The cookie holds only a signed session id; the session itself lives in the database, so it can
# expire and be revoked on the server (logging out invalidates a copied cookie).
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :session_id

  included do
    before_action :require_authentication
    after_action :note_user_for_api_monitor
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def require_authentication
    resume_session || render_error(:unauthenticated, "Please sign in to continue", status: :unauthorized)
  end

  # The API monitor's middleware runs outside the controllers, so the signed-in user is left in the request for it.
  def note_user_for_api_monitor
    request.env[ApiMonitor::USER_ENV_KEY] = Current.user&.id
  end

  def resume_session
    Current.session ||= find_session_from_cookie
  end

  def find_session_from_cookie
    session_id = cookies.signed[SESSION_COOKIE]
    Session.active.find_by(id: session_id) if session_id
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed[SESSION_COOKIE] = {
        value: session.id,
        httponly: true,
        same_site: :lax,
        secure: Rails.configuration.force_ssl,
        expires: Session::EXPIRES_AFTER.from_now
      }
    end
  end

  def terminate_session
    Current.session.destroy
    cookies.delete(SESSION_COOKIE)
  end
end
