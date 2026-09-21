require "test_helper"

class AdminAssetsHelperTest < ActionView::TestCase
  include AdminAssetsHelper

  test "an asset's address carries a version taken from its content" do
    path = admin_asset_path("admin.css")

    assert_match(%r{\A/admin-assets/admin\.css\?v=[0-9a-f]{10}\z}, path)
    assert_equal Digest::SHA1.file(Rails.public_path.join("admin-assets", "admin.css")).hexdigest.first(10), path[/v=(\w+)/, 1]
  end

  test "the same content always gets the same version, so the browser can keep it" do
    assert_equal admin_asset_path("admin.js"), admin_asset_path("admin.js")
  end

  test "an asset in a folder is found too" do
    assert_match(%r{\A/admin-assets/fonts/montserrat-latin-wght-normal\.woff2\?v=[0-9a-f]{10}\z},
                 admin_asset_path("fonts/montserrat-latin-wght-normal.woff2"))
  end

  test "a file that is not there is an error, not a link that quietly breaks" do
    assert_raises(ArgumentError) { admin_asset_path("nope.css") }
  end

  test "a path that climbs out of the folder is refused" do
    assert_raises(ArgumentError) { admin_asset_path("../../config/database.yml") }
    assert_raises(ArgumentError) { admin_asset_path("/etc/passwd") }
  end
end
