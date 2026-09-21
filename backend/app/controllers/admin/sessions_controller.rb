module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
      render plain: "Too many sign-in attempts. Try again later.", status: :too_many_requests
    }

    def new
      redirect_to admin_root_path if current_admin
    end

    def create
      admin = authenticate(params[:email], params[:password])

      if admin
        start_admin_session(admin)
        redirect_to admin_root_path
      else
        @error = "Invalid email or password"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      end_admin_session
      redirect_to admin_login_path
    end

    private

    # An unknown email, a wrong password and an account that is not an administrator are indistinguishable.
    def authenticate(email, password)
      return if email.blank? || password.blank?

      user = User.authenticate_by(email: email.to_s, password: password.to_s)
      user if user&.admin?
    end
  end
end
