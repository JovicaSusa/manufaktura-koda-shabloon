# manufaktura-koda-shabloon

## What this is

A **Rails application template** — not a runnable app. It is used to bootstrap new Rails projects:

```bash
rails new myapp -m template.rb
```

The only real files are `template.rb` (249 lines, the full installer) and `templates/database_pg.yml.tt` (ERB template for PostgreSQL `database.yml`).

## What the generated app gets

**Database**
- PostgreSQL replaces SQLite
- Multi-database in production: primary, cache, queue, cable, rails\_pulse
- Separate `rails_pulse` database in all environments (dev, test, production)

**Auth & Authorization**
- Devise (authentication)
- Action Policy (authorization — declarative policy objects)

**Frontend**
- Inertia.js + Vite (SPA-like, server-driven with TypeScript support)
- js-routes gem (Rails routes exposed to JavaScript)
- Typelizer (generates TypeScript types from Ruby)

**Serialization**
- Alba + alba-inertia (lightweight JSON serializers — not JBuilder)

**Background Jobs (optional)**
- Solid Queue + Mission Control Jobs dashboard

**Monitoring & Performance Dashboards**
| Path | Tool | Purpose |
|------|------|---------|
| `/rails_pulse` | RailsPulse | App monitoring |
| `/pghero` | PgHero | Postgres performance |
| `/letter_opener` | Letter Opener Web | Email preview (dev only) |
| `/jobs` | Mission Control | Job queue (if Solid Queue enabled) |

**Deployment (Kamal)**
- `config/deploy.yml` — always generated, single Hetzner server setup
- Architecture: `web` role + `workers` role (if Solid Queue) on the same host; Hetzner Managed PostgreSQL is external (no DB accessory)
- Three placeholders to fill after generation: `YOUR_SERVER_IP`, `your-app.example.com`, `your-user` (registry)
- DB credentials (`DB_HOST`, `DB_USERNAME`, `DB_PASSWORD`) go in `.kamal/secrets` and shell env
- First deploy: `kamal setup`

**Testing**
- RSpec (`rspec-rails`) — installed via `generate "rspec:install"`, support files auto-loaded from `spec/support/`
- Factory Bot (`factory_bot_rails` + `faker`) — syntax methods included globally, factories in `spec/factories/`
- Shoulda Matchers — wired to RSpec + Rails in `spec/support/shoulda_matchers.rb`

**CI (GitHub Actions)**
- `.github/workflows/ci.yml` — always generated, two jobs:
  - `lint`: Standard/RuboCop (`rubocop --parallel`)
  - `test`: Postgres 16 service + `rails db:create db:schema:load` + `rails test`
- Ruby version in the workflow matches the RuboCop prompt answer
- DB credentials injected via `DB_HOST/DB_USERNAME/DB_PASSWORD` env vars (matches `database.yml` defaults)

**Code Quality**
- Standard + standard-rails + rubocop-rspec (Evil Martians style)
- Prosopite (N+1 detection, wired into ApplicationController)
- Strong Migrations (blocks unsafe migrations)
- Database Consistency + Database Validations
- Isolator (detects non-atomic interactions)

**Email**
- Letter Opener Web (dev preview)
- Premailer (CSS inlining for production emails)

**Dev Tools**
- Rack Mini Profiler + Stackprof
- Evil Seed (anonymized DB dumps)
- Silencer (suppress noisy logs)
- Freezolite (frozen string literals)
- Bundlebun

## Interactive prompts during generation

The template asks the user:
1. Install Solid Queue for background jobs? (y/n)
2. Generate a Devise model? (y/n) → if yes: model name
3. Copy Devise views for customization? (y/n)
4. Mission Control dashboard username (default: admin) + password (default: secret)
5. PgHero dashboard username (default: admin) + password (default: secret)
6. Set up PgHero query stats tracking? (y/n)
7. Target Ruby version for RuboCop (default: 3.3)

## Key conventions enforced

- Ruby style: Standard (Evil Martians flavour), not RuboCop defaults
- Serializers: Alba, never JBuilder
- Authorization: Action Policy (policy objects), not CanCanCan/Pundit
- Frontend: Inertia.js (server renders props, client renders components) — no separate API layer
- N+1 guard: Prosopite middleware added to ApplicationController in development
- Migrations: Strong Migrations blocks destructive operations

## How to extend the template

All setup logic lives in `template.rb`. The file is linear: gem declarations first, then `after_bundle` blocks that run configuration steps. To add a new tool:

1. Add `gem "..."` (or `gem "...", group: :development`) near related gems
2. Add an `after_bundle` block that runs generators, copies config, or appends to files using Rails template helpers (`generate`, `gsub_file`, `append_to_file`, `copy_file`, etc.)
3. Add a `.tt` template file under `templates/` if the tool needs a config file rendered with app-specific variables
