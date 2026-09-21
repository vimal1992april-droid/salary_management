require "test_helper"

class ApiRequestTest < ActiveSupport::TestCase
  test "names the class of its status" do
    assert_equal "2xx", build(:api_request, status: 201).status_class
    assert_equal "3xx", build(:api_request, status: 304).status_class
    assert_equal "4xx", build(:api_request, status: 404).status_class
    assert_equal "5xx", build(:api_request, status: 503).status_class
  end

  test "tells a failure of the server from a mistake of the caller" do
    assert build(:api_request, status: 500).server_error?
    assert_not build(:api_request, status: 422).server_error?
    assert build(:api_request, status: 422).client_error?
    assert_not build(:api_request, status: 200).client_error?
  end

  test "knows the user who made it, and still stands when that user is gone" do
    user = create(:user)
    request = create(:api_request, user_id: user.id)

    assert_equal user, request.user

    user.destroy!
    assert_nil request.reload.user
    assert_predicate request, :persisted?
  end

  test "is not changed once recorded" do
    request = create(:api_request)

    assert_predicate request.reload, :readonly?
  end

  test "prune! keeps only the newest rows" do
    older = create_list(:api_request, 3)
    newest = create_list(:api_request, 2)

    deleted = ApiRequest.prune!(keep: 2)

    assert_equal 3, deleted
    assert_equal newest.map(&:id).sort, ApiRequest.pluck(:id).sort
    assert_empty ApiRequest.where(id: older.map(&:id))
  end

  test "prune! does nothing when there are fewer rows than it may keep" do
    create_list(:api_request, 2)

    assert_equal 0, ApiRequest.prune!(keep: 5)
    assert_equal 2, ApiRequest.count
  end
end
