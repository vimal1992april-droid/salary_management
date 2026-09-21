module Api
  # Reference data behind the directory filters and the employee form.
  class LookupsController < ApplicationController
    def show
      render json: {
        countries: Country.order(:name).as_json(only: %i[id name iso_code currency_code]),
        departments: Department.order(:name).as_json(only: %i[id name]),
        job_titles: JobTitle.order(:name).as_json(only: %i[id name level]),
        currencies: Currency.order(:code).as_json(only: %i[code name rate_to_usd rate_as_of])
      }
    end
  end
end
