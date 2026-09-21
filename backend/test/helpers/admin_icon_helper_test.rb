require "test_helper"

class AdminIconHelperTest < ActionView::TestCase
  include AdminIconHelper

  def svg(name, **options)
    Nokogiri::XML(admin_icon(name, **options)) { |config| config.strict }.root
  end

  test "an icon is an inline SVG drawn with the text colour, hidden from screen readers" do
    icon = svg(:grid)

    assert_equal "svg", icon.name
    assert_equal "icon", icon["class"]
    assert_equal "true", icon["aria-hidden"]
    assert_equal "0 0 24 24", icon["viewBox"]
    assert_equal "currentColor", icon["stroke"]
    assert_equal "none", icon["fill"]
  end

  test "an icon can take an extra class" do
    assert_equal "icon spin", svg(:refresh, class: "spin")["class"]
  end

  test "an icon that does not exist is an error, so a typo is found at once" do
    assert_raises(ArgumentError) { admin_icon(:not_an_icon) }
  end

  test "every icon is well-formed and draws something" do
    AdminIconHelper::ICONS.each_key do |name|
      icon = svg(name)

      assert_operator icon.element_children.size, :>=, 1, "#{name} draws nothing"
    end
  end

  test "has the icons the panel uses" do
    %i[grid database table activity list sun moon menu copy check users log_out dollar globe briefcase trending
       clock alert server refresh search x].each do |name|
      assert_includes AdminIconHelper::ICONS, name
    end
  end
end
