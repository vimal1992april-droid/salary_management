require "test_helper"

class ApiMonitor::RedactorTest < ActiveSupport::TestCase
  JSON_TYPE = "application/json".freeze

  def redact(body, content_type: JSON_TYPE, **options)
    ApiMonitor::Redactor.call(body, content_type: content_type, **options)
  end

  test "nothing to record for an empty body" do
    [ nil, "" ].each do |body|
      result = redact(body)

      assert_nil result.text
      assert_not result.truncated
    end
  end

  test "keeps a JSON body readable and hides the secrets in it" do
    result = redact({ email: "asha@acme.example", password: "hunter2-hunter2" }.to_json)

    assert_equal({ "email" => "asha@acme.example", "password" => "[FILTERED]" }, JSON.parse(result.text))
    assert_not_includes result.text, "hunter2"
  end

  test "finds secrets however deep they are, and however the key is spelled" do
    body = { user: { session_token: "abc123" }, items: [ { "API_SECRET" => "x1" }, { "Password" => "x2" } ],
             passwordConfirmation: "x3", authorization: "Bearer x4", password_digest: "x5" }.to_json

    text = redact(body).text

    %w[abc123 x1 x2 x3 x4 x5].each { |secret| assert_not_includes text, secret }
    assert_equal 6, text.scan("[FILTERED]").size
  end

  test "leaves business data alone: names, emails and salaries are what the admin came to see" do
    body = { first_name: "Asha", email: "asha@acme.example", salary_amount: "90000.0", job_title: "Engineer" }.to_json

    assert_equal JSON.parse(body), JSON.parse(redact(body).text)
  end

  test "reads a form the same way, and shows it as JSON" do
    result = redact("email=asha%40acme.example&password=hunter2", content_type: "application/x-www-form-urlencoded")

    assert_equal({ "email" => "asha@acme.example", "password" => "[FILTERED]" }, JSON.parse(result.text))
  end

  test "the content type is read whatever its parameters" do
    result = redact({ password: "hunter2" }.to_json, content_type: "application/json; charset=utf-8")

    assert_not_includes result.text, "hunter2"
  end

  test "does not record what it cannot read for secrets, only what it is" do
    result = redact("id,name\n1,Asha\n", content_type: "text/csv")

    assert_equal "[text/csv, 15 bytes, not recorded]", result.text
    assert_not result.truncated
  end

  test "does not record a body that claims to be JSON but is not" do
    result = redact("{ password: hunter2 ", content_type: JSON_TYPE)

    assert_equal "[unreadable JSON, 20 bytes, not recorded]", result.text
    assert_not_includes result.text, "hunter2"
  end

  test "does not record a body without a content type" do
    assert_equal "[unknown type, 3 bytes, not recorded]", redact("abc", content_type: nil).text
  end

  test "does not record a form body whose keys cannot agree on being a list or a hash" do
    body = "foo[]=1&foo[bar]=2"

    result = redact(body, content_type: "application/x-www-form-urlencoded")

    assert_equal "[unreadable form, #{body.bytesize} bytes, not recorded]", result.text
  end

  test "cuts a long body short and says so, without splitting a character" do
    body = { names: [ "é" * 300 ] }.to_json

    result = redact(body, limit: 100)

    assert result.truncated
    assert_operator result.text.bytesize, :<=, 100
    assert_predicate result.text, :valid_encoding?
    assert result.text.start_with?('{"names"')
  end

  test "a body under the limit is not marked as cut" do
    assert_not redact({ a: 1 }.to_json, limit: 100).truncated
  end

  test "does not even parse a body too large to be worth it" do
    result = redact("x" * 60, max_bytes: 50)

    assert_equal "[body of 60 bytes, too large to record]", result.text
    assert result.truncated
  end

  # --- query strings ------------------------------------------------------------------------------------------------------

  test "hides secrets in a query string and keeps the rest" do
    query = ApiMonitor::Redactor.query_string("q=asha&page=2&access_token=abc123")

    assert_equal({ "q" => "asha", "page" => "2", "access_token" => "[FILTERED]" }, Rack::Utils.parse_query(query))
    assert_not_includes query, "abc123"
  end

  test "an empty query string is nothing" do
    assert_nil ApiMonitor::Redactor.query_string("")
    assert_nil ApiMonitor::Redactor.query_string(nil)
  end

  test "a query string whose keys cannot agree on being a list or a hash is reported, not parsed" do
    assert_equal "[unreadable query string]", ApiMonitor::Redactor.query_string("foo[]=1&foo[bar]=2")
  end
end
