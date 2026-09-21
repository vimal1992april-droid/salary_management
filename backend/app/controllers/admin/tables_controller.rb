module Admin
  class TablesController < BaseController
    def index
      @tables = Admin::Table.all.map { |table| [ table, table.count ] }
    end

    def show
      @table = Admin::Table.find!(params[:table])
      @filters = filters
      @result = @table.page(q: params[:q], sort: params[:sort], direction: params[:direction], page: params[:page],
                            per_page: params[:per_page], filters: @filters)
    end

    private

    # `?filter[employee_id]=5`: only plain values for columns of this table are kept, the rest is dropped.
    def filters
      given = params[:filter]
      return {} unless given.respond_to?(:to_unsafe_h)

      given.to_unsafe_h.select { |column, value| @table.columns.include?(column) && value.is_a?(String) && value.present? }
    end
  end
end
