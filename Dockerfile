# syntax=docker/dockerfile:1
#
# One image for the whole product: Rails serves the built React app, so there is a single origin and one
# thing to deploy. Build from the repository root:  docker build -t salary-management .
#
#   docker run -p 3000:3000 -e DATABASE_URL=postgres://... -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
#              -e HR_EMAIL=hr@example.com -e HR_PASSWORD=... salary-management
#
# Behind a TLS-terminating proxy (Render, Fly.io, ...) no further setup is needed. To try it over plain HTTP,
# also pass -e FORCE_SSL=false.

ARG RUBY_VERSION=3.4.6

# ---- 1. Build the React app -------------------------------------------------------------------------------------
FROM node:22-slim AS frontend
WORKDIR /frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# ---- 2. Base for the Rails stages -------------------------------------------------------------------------------
FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /app
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"
RUN apt-get update -qq \
 && apt-get install --no-install-recommends -y libpq5 curl \
 && rm -rf /var/lib/apt/lists/*

# ---- 3. Install the gems (build tools stay in this stage) -------------------------------------------------------
FROM base AS build
RUN apt-get update -qq \
 && apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*
COPY backend/Gemfile backend/Gemfile.lock ./
RUN bundle install \
 && rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git
COPY backend/ ./
RUN bundle exec bootsnap precompile app lib

# ---- 4. The runtime image ---------------------------------------------------------------------------------------
FROM base
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /app /app
# The built React app goes in public/: index.html for the pages, assets/ for the hashed files.
COPY --from=frontend /frontend/dist /app/public

RUN groupadd --system --gid 1000 rails \
 && useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash \
 && chown -R rails:rails log tmp storage db
USER 1000:1000

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s \
  CMD curl -fs "http://localhost:${PORT:-3000}/up" || exit 1
CMD ["bin/start-production"]
