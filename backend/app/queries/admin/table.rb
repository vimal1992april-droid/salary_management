module Admin
  # One table of the database as the admin panel shows it: read-only, paged, searchable, sortable and filterable.
  #
  #   table = Admin::Table.find!("employees")   # only tables on the list below; a name from a URL never reaches SQL
  #   result = table.page(q: "asha", sort: "hire_date", direction: "desc", page: 2)
  #   result.records / result.total / result.total_pages
  #
  # Sort, search and filter columns are checked against the table's visible columns, and anything else is ignored, so
  # a hand-edited URL cannot make the page fail or reach a column that is meant to stay hidden.
  class Table
    # The tables shown, in the order shown.
    MODELS = %w[Employee SalaryChange Department JobTitle Country Currency User Session].freeze
    # Columns that are never selected, shown, searched or sorted on.
    HIDDEN_COLUMNS = { "users" => %w[password_digest] }.freeze
    TIMESTAMPS = %w[created_at updated_at].freeze
    DIRECTIONS = %w[asc desc].freeze
    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100
    MAX_ID_DIGITS = 18 # a bigint holds 19; anything longer cannot be an id

    Result = Struct.new(:records, :page, :per_page, :total) do
      def total_pages
        [ (total.to_f / per_page).ceil, 1 ].max
      end
    end

    def self.all
      MODELS.map { |name| new(name.constantize) }
    end

    def self.find!(name)
      all.find { |table| table.name == name.to_s } || raise(ActiveRecord::RecordNotFound, "No table named #{name}")
    end

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def name
      model.table_name
    end

    def title
      name.humanize
    end

    def count
      model.count
    end

    def primary_key
      model.primary_key
    end

    # The visible columns: the key first, the timestamps last, the rest alphabetically. The database's own order is not
    # used because it depends on how the database was built (migrated step by step, or loaded from the schema file).
    def columns
      @columns ||= begin
        visible = model.column_names - HIDDEN_COLUMNS.fetch(name, [])
        edges = [ model.primary_key, *TIMESTAMPS ]
        [ model.primary_key ] + (visible - edges).sort + (TIMESTAMPS & visible)
      end
    end

    # Columns that hold the key of a row in another listed table: { "country_id" => "countries" }.
    def links
      @links ||= model.reflect_on_all_associations(:belongs_to).each_with_object({}) do |association, links|
        target = association.klass.table_name
        links[association.foreign_key.to_s] = target if MODELS.any? { |model_name| model_name.constantize.table_name == target }
      end
    end

    # The rows of other tables that point at a row of this one, counted: which table, through which column.
    def related_counts(record)
      key = record[model.primary_key]

      self.class.all.flat_map do |other|
        other.links.select { |_column, target| target == name }.map do |column, _target|
          { table: other.name, column: column, count: other.model.where(column => key).count }
        end
      end
    end

    def find_record(id)
      model.select(*columns).find(id)
    end

    def attributes_of(record)
      columns.index_with { |column| record[column] }
    end

    def page(q: nil, sort: nil, direction: nil, page: nil, per_page: nil, filters: {})
      scope = filter(search(model.all, q), filters)
      total = scope.count
      per_page = per_page_from(per_page)
      page = page_from(page, total, per_page)

      records = sort_by(scope.select(*columns), sort, direction).limit(per_page).offset((page - 1) * per_page).to_a
      Result.new(records, page, per_page, total)
    end

    private

    def search(scope, q)
      q = q.to_s.strip
      return scope if q.empty?

      pattern = "%#{model.sanitize_sql_like(q)}%"
      matches = text_columns.map { |column| model.arel_table[column].matches(pattern, nil, false) }
      matches << model.arel_table[model.primary_key].eq(q.to_i) if id_like?(q)
      scope.where(matches.reduce(:or))
    end

    def text_columns
      model.columns.select { |column| columns.include?(column.name) && %i[string text].include?(column.type) }.map(&:name)
    end

    def id_like?(q)
      q.match?(/\A\d{1,#{MAX_ID_DIGITS}}\z/) && model.type_for_attribute(model.primary_key).type == :integer
    end

    def filter(scope, filters)
      filters.to_h.reduce(scope) do |narrowed, (column, value)|
        next narrowed unless columns.include?(column.to_s) && (value.is_a?(String) || value.is_a?(Numeric)) && value.to_s != ""

        narrowed.where(column.to_s => value.to_s)
      end
    end

    def sort_by(scope, sort, direction)
      key = model.arel_table[model.primary_key].asc
      return scope.order(key) unless columns.include?(sort.to_s)

      direction = DIRECTIONS.include?(direction.to_s) ? direction.to_s : "asc"
      scope.order(model.arel_table[sort.to_s].public_send(direction), key)
    end

    def per_page_from(value)
      number = Integer(value.to_s, 10, exception: false)
      number && number.positive? ? [ number, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
    end

    # Past the last page is the last page, and below the first is the first.
    def page_from(value, total, per_page)
      last = [ (total.to_f / per_page).ceil, 1 ].max
      (Integer(value.to_s, 10, exception: false) || 1).clamp(1, last)
    end
  end
end
