module Admin
  # The paging rules shared by every list in the admin panel: 25 rows by default, at most 100, and a page or size that
  # makes no sense (text, zero, negative, past the end) is put right instead of failing.
  module Pagination
    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100

    Result = Struct.new(:records, :page, :per_page, :total) do
      def total_pages
        [ (total.to_f / per_page).ceil, 1 ].max
      end
    end

    module_function

    def per_page(value)
      number = Integer(value.to_s, 10, exception: false)
      number && number.positive? ? [ number, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
    end

    # Past the last page is the last page, and below the first is the first.
    def page(value, total, per_page)
      last = [ (total.to_f / per_page).ceil, 1 ].max
      (Integer(value.to_s, 10, exception: false) || 1).clamp(1, last)
    end
  end
end
