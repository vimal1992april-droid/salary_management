module Api
  # Downloads the directory as a CSV file, using the same filters, search and sort as the employee list.
  class EmployeeExportsController < ApplicationController
    include EmployeeSearchable

    def show
      employees = Employees::Search.call(**search_params, paginate: false).records

      send_data Employees::CsvExport.call(employees),
                filename: "employees-#{Date.current.iso8601}.csv",
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    end
  end
end
