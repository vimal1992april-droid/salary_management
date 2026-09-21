module Admin
  class RecordsController < BaseController
    def show
      @table = Admin::Table.find!(params[:table])
      @record = @table.find_record(params[:id])
      @related = @table.related_counts(@record)
    end
  end
end
