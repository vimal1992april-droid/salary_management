# Frontend

The HR manager's React + TypeScript app (Vite). The whole product is described in the
[repository README](../README.md); the Rails API it talks to is in [`../backend`](../backend).

## Run it

Start the Rails server first (`cd ../backend && bin/rails server`, port 3000), then:

```bash
npm install
npm run dev     # http://localhost:5173, proxies /api to Rails
npm test        # 155 tests
```

## Signing in

Open http://localhost:5173 and sign in as the HR manager with **`hr@acme.example` / `salary-manager-demo`** (created
by `bin/rails db:seed` in development; elsewhere set `HR_EMAIL` and `HR_PASSWORD` on the server).

The **administrator's panel is not part of this app**: it is served by Rails at http://localhost:3000/admin, with its
own login (**`admin@acme.example` / `admin-panel-demo`**). The HR login does not open it. See
[Signing in](../README.md#signing-in) in the main README.

---

The rest of this file is the Vite template's own notes.

# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some Oxlint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend enabling type-aware lint rules by installing `oxlint-tsgolint` and editing `.oxlintrc.json`:

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "oxc"],
  "options": {
    "typeAware": true
  },
  "rules": {
    "react/rules-of-hooks": "error",
    "react/only-export-components": ["warn", { "allowConstantExport": true }]
  }
}
```

See the [Oxlint rules documentation](https://oxc.rs/docs/guide/usage/linter/rules) for the full list of rules and categories.
