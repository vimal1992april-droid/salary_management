require "test_helper"

# A script with Windows line endings fails on Linux with an error that does not say so: "#!/bin/bash -e\r" asks for a
# shell called "bash -e\r", and the production container exits at once with "invalid option". Editing on Windows
# against a Linux checkout can put them in without anyone noticing, so this fails the build instead.
class LineEndingsTest < ActiveSupport::TestCase
  ROOTS = %w[app bin config db lib test].freeze

  def text_files
    ROOTS.flat_map { |root| Dir.glob(Rails.root.join(root, "**", "*")) }
         .select { |path| File.file?(path) }
         .reject { |path| File.binread(path, 4096).include?("\0") }
  end

  test "no source file or script uses Windows line endings" do
    offenders = text_files.select { |path| File.binread(path).include?("\r\n") }

    assert_empty offenders.map { |path| Pathname(path).relative_path_from(Rails.root).to_s }
  end

  test "every script in bin starts with a plain shebang line" do
    scripts = Dir.glob(Rails.root.join("bin", "*")).select { |path| File.file?(path) && File.binread(path, 2) == "#!" }

    assert_not_empty scripts
    scripts.each do |path|
      first_line = File.open(path, &:readline)

      assert_no_match(/\r/, first_line, "#{File.basename(path)} has a carriage return in its shebang line")
    end
  end
end
