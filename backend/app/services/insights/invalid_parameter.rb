module Insights
  # Raised for a parameter that names something that does not exist (a grouping, a direction).
  class InvalidParameter < ArgumentError; end
end
