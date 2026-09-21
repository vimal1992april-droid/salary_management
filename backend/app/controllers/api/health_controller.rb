module Api
  class HealthController < ApplicationController
    allow_unauthenticated_access

    def show
      render json: { status: "ok", database: database_up?, rails: Rails.version }
    end

    private

    def database_up?
      ActiveRecord::Base.connection.select_value("SELECT 1") == 1
    rescue ActiveRecord::ActiveRecordError
      false
    end
  end
end
