require "digest"

# Addresses of the admin panel's own files (public/admin-assets): the stylesheet, the script and the font.
#
# Production tells browsers to keep files under public/ for a year, so an address that never changes would leave a
# browser with yesterday's stylesheet after a deploy. The address therefore carries a version taken from the file's
# content: change the file and the address changes with it. (The font files are the exception, referred to by the
# stylesheet without a version; if one ever changes it gets a new name.)
module AdminAssetsHelper
  FOLDER = "admin-assets".freeze
  VERSIONS = Concurrent::Map.new

  # "/admin-assets/admin.css?v=3f9a1c02de". A file that is not there is an error, so a typo is found at once rather
  # than becoming a link that quietly breaks; so is a path that climbs out of the folder.
  def admin_asset_path(name)
    file = admin_asset_file(name)

    "/#{FOLDER}/#{name}?v=#{admin_asset_version(file)}"
  end

  private

  def admin_asset_file(name)
    root = Rails.public_path.join(FOLDER)
    file = root.join(name.to_s).cleanpath
    raise ArgumentError, "No admin asset named #{name.inspect}" unless file.to_s.start_with?("#{root}/") && file.file?

    file
  end

  # Read again only when the file has changed (its size or modification time), so a page does not re-read its files.
  def admin_asset_version(file)
    stamp = [ file.mtime.to_f, file.size ]
    known = VERSIONS[file.to_s]
    return known[:version] if known && known[:stamp] == stamp

    Digest::SHA1.file(file).hexdigest.first(10).tap { |version| VERSIONS[file.to_s] = { stamp: stamp, version: version } }
  end
end
