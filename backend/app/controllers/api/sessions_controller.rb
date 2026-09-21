module Api
  class SessionsController < ApplicationController
    allow_unauthenticated_access only: :create
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
      render_error(:rate_limited, "Too many login attempts. Try again later.", status: :too_many_requests)
    }

    def show
      render json: { user: UserSerializer.new(Current.user) }
    end

    def create
      user = authenticate(params[:email], params[:password])
      return render_error(:invalid_credentials, "Invalid email or password", status: :unauthorized) unless user

      start_new_session_for(user)
      render json: { user: UserSerializer.new(user) }, status: :created
    end

    def destroy
      terminate_session
      head :no_content
    end

    private

    # An unknown email and a wrong password are indistinguishable to the caller.
    def authenticate(email, password)
      return if email.blank? || password.blank?

      User.authenticate_by(email: email.to_s, password: password.to_s)
    end
  end
end
