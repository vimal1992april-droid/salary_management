# Salary Management

Rails 8 API (`backend/`) with a React + TypeScript frontend built on Vite (`frontend/`).

## Requirements

- Ruby 3.2+, Bundler
- Node 20+
- PostgreSQL 16 (the default local role must be able to create databases)

## Setup

```bash
cd backend
bundle install
bin/rails db:create db:migrate

cd ../frontend
npm install
```

## Run

Start both servers, each in its own terminal:

```bash
cd backend && bin/rails server        # http://localhost:3000
cd frontend && npm run dev            # http://localhost:5173
```

In development the Vite dev server proxies `/api/*` to Rails, so the frontend calls
relative URLs such as `/api/health`.

## Test

```bash
cd backend && bin/rails test
cd frontend && npm run lint && npm run build
```
