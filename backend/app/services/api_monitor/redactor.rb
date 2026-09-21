module ApiMonitor
  # Decides what of a request or response body may be kept. A body that can be read for secrets keeps its shape with
  # every value under a secret-looking key replaced; one that cannot (CSV, malformed JSON, unknown types, huge bodies)
  # is described, never stored.
  #
  # Email addresses and pay are left as they are: they are the data the administrator is there to see, and are already
  # browsable in the data pages.
  module Redactor
    Result = Data.define(:text, :truncated)

    FILTERED = "[FILTERED]".freeze
    # Matched anywhere in a key, ignoring case: "passw" also catches Password and password_digest.
    SECRET_KEYS = %i[passw secret token _key crypt salt certificate otp ssn cvv cvc digest authorization cookie].freeze
    FILTER = ActiveSupport::ParameterFilter.new(SECRET_KEYS, mask: FILTERED)

    STORE_LIMIT = 20_000 # bytes kept of one payload
    MAX_PARSE_BYTES = 1_000_000 # a body larger than this is not even read

    module_function

    def call(body, content_type:, limit: STORE_LIMIT, max_bytes: MAX_PARSE_BYTES)
      return Result.new(nil, false) if body.blank?

      body = body.to_s
      return Result.new("[body of #{body.bytesize} bytes, too large to record]", true) if body.bytesize > max_bytes

      value, description = read(body, media_type(content_type))
      return Result.new(description, false) if description

      text, truncated = cut(JSON.generate(filter(value)), limit)
      Result.new(text, truncated)
    end

    def query_string(raw)
      return if raw.blank?

      Rack::Utils.build_nested_query(filter(Rack::Utils.parse_nested_query(raw)))
    rescue Rack::QueryParser::QueryLimitError, Rack::QueryParser::ParameterTypeError, Rack::QueryParser::InvalidParameterError
      "[unreadable query string]"
    end

    # [the parsed body, nil], or [nil, why it is not being recorded].
    def read(body, type)
      case type
      when "application/x-www-form-urlencoded"
        [ Rack::Utils.parse_nested_query(body), nil ]
      when "application/json", /\+json\z/
        [ JSON.parse(body), nil ]
      else
        [ nil, "[#{type || 'unknown type'}, #{body.bytesize} bytes, not recorded]" ]
      end
    rescue JSON::ParserError
      [ nil, "[unreadable JSON, #{body.bytesize} bytes, not recorded]" ]
    rescue Rack::QueryParser::QueryLimitError, Rack::QueryParser::ParameterTypeError, Rack::QueryParser::InvalidParameterError
      [ nil, "[unreadable form, #{body.bytesize} bytes, not recorded]" ]
    end
    private_class_method :read

    def media_type(content_type)
      content_type.to_s.split(";").first.to_s.strip.downcase.presence
    end
    private_class_method :media_type

    # The filter works on hashes, so any value is wrapped in one: a top-level array or string is filtered the same way.
    def filter(value)
      FILTER.filter("body" => value)["body"]
    end
    private_class_method :filter

    def cut(text, limit)
      return [ text, false ] if text.bytesize <= limit

      [ text.byteslice(0, limit).scrub(""), true ]
    end
    private_class_method :cut
  end
end
