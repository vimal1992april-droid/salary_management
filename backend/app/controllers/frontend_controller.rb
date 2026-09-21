# Serves the built React app (in production, public/index.html). Pages are client-side routes, so any browser
# URL that is not the API returns this shell, and the app decides what to show, including the sign-in page.
class FrontendController < ApplicationController
  allow_unauthenticated_access

  def index
    # The setting is read once, when a server starts, so fall back for one that started before it existed.
    index = Rails.configuration.x.frontend_index || Rails.public_path.join("index.html")

    if File.exist?(index)
      send_file index, type: "text/html", disposition: "inline"
      # The shell names the hashed assets of one build, so it must be re-checked each visit; the assets themselves
      # are immutable and cached for a year by the static file server.
      response.headers["Cache-Control"] = "no-cache"
    else
      render plain: "The frontend has not been built.\n\n" \
                    "Developing? Rails on this port is only the API. Open the app at http://localhost:5173 (npm run dev in frontend/).\n" \
                    "Deploying? Run `npm run build` in frontend/ and copy dist/ into backend/public/ (the Dockerfile does this).",
             status: :not_found
    end
  end
end
