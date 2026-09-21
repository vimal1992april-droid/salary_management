require "test_helper"

# The files behind the admin panel's look: they must exist, be served, and keep to what was promised (Montserrat, from
# this app, light and dark, usable on a phone).
class AdminAssetsTest < ActionDispatch::IntegrationTest
  FOLDER = Rails.public_path.join("admin-assets")
  FONTS = %w[montserrat-latin-wght-normal.woff2 montserrat-latin-ext-wght-normal.woff2].freeze

  def stylesheet
    File.read(FOLDER.join("admin.css"))
  end

  test "the stylesheet, the script and both font files are served with the right types" do
    { "admin.css" => %r{text/css}, "admin.js" => /javascript/,
      "fonts/#{FONTS.first}" => %r{font/woff2}, "fonts/#{FONTS.last}" => %r{font/woff2} }.each do |file, type|
      get "/admin-assets/#{file}"

      assert_response :success, file
      assert_match type, response.media_type, file
      assert_not_includes response.body[0, 200], %(<div id="root">), "#{file} was answered by the React app"
    end
  end

  test "an asset that is not there is a plain 404, not the React app" do
    get "/admin-assets/nope.css"

    assert_response :not_found
    assert_not_includes response.body, %(<div id="root">)
  end

  test "the text is set in Montserrat, with sensible fallbacks" do
    assert_match(/font-family:\s*"Montserrat",\s*system-ui/, stylesheet)
  end

  test "Montserrat is declared for a whole range of weights and is shown at once, not after it loads" do
    faces = stylesheet.scan(/@font-face\s*\{[^}]*\}/m)

    assert_equal 2, faces.size
    faces.each do |face|
      assert_includes face, 'font-family: "Montserrat"'
      assert_match(/font-weight:\s*100 900/, face)
      assert_includes face, "font-display: swap"
      assert_includes face, "unicode-range"
      assert_match(/format\("woff2"\)/, face)
    end
  end

  test "every font, image or file the stylesheet refers to exists" do
    urls = stylesheet.scan(/url\(\s*["']?([^"')]+)["']?\s*\)/).flatten

    assert_operator urls.size, :>=, 2
    urls.each do |url|
      assert url.start_with?("/admin-assets/"), "#{url} is not under /admin-assets"
      assert File.file?(Rails.public_path.join(url.delete_prefix("/"))), "#{url} does not exist"
    end
  end

  test "the font's licence travels with it" do
    licence = FOLDER.join("fonts", "OFL.txt")

    assert File.file?(licence)
    assert_includes File.read(licence), "SIL OPEN FONT LICENSE"
    assert_includes File.read(licence), "Montserrat"
  end

  test "nothing in the stylesheet or the script reaches another site" do
    [ stylesheet, File.read(FOLDER.join("admin.js")) ].each do |source|
      assert_no_match %r{https?://}, source
    end
  end

  test "the stylesheet has a dark theme, a phone layout and respects reduced motion" do
    assert_includes stylesheet, %([data-theme="dark"])
    assert_match(/@media \(max-width:\s*\d+px\)/, stylesheet)
    assert_includes stylesheet, "prefers-reduced-motion"
  end

  test "numbers line up in columns" do
    assert_includes stylesheet, "tabular-nums"
  end
end
