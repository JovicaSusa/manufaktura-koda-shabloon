# Rails Application Template

An opinionated Rails application template for building web apps as products. Run it once with `rails new` and get a fully configured app with authentication, a modern frontend, background jobs, deployment, CI, and a suite of development tools — all wired together and ready to go.

## Prerequisites

Before using this template, make sure you have installed:

- Ruby 3.3+
- Rails 8+
- PostgreSQL (running locally)
- [Bun](https://bun.sh) (JavaScript runtime, used instead of Node/npm)
- A Docker Hub or GitHub Container Registry account (for deployment)

## Usage

```bash
rails new myapp -m /path/to/template.rb
cd myapp
bin/dev
```

You can also point directly at the GitHub URL:

```bash
rails new myapp -m https://raw.githubusercontent.com/JovicaSusa/manufaktura-koda-shabloon/main/template.rb
```

## Interactive prompts

The template will ask a series of questions during generation. You can accept the defaults or customize:

| Prompt | Default | Notes |
|--------|---------|-------|
| Install Solid Queue? | — | Adds background job processing + Mission Control dashboard |
| Generate a Devise model? | — | Recommended; creates your User (or other) model |
| Model name | `User` | The name of the Devise authentication model |
| Copy Devise views? | — | Useful when you need to customize sign-in/sign-up HTML |
| Mission Control username | `admin` | Basic auth for the `/jobs` dashboard |
| Mission Control password | `secret` | Change this before deploying |
| PgHero username | `admin` | Basic auth for the `/pghero` dashboard |
| PgHero password | `secret` | Change this before deploying |
| Set up PgHero query stats? | — | Adds a migration to track slow queries over time |
| Target Ruby version (RuboCop) | `3.3` | Should match the Ruby version in your `.ruby-version` |

## What you get

### Database

PostgreSQL replaces SQLite. In production, five separate databases are configured to isolate concerns:

| Database | Purpose |
|----------|---------|
| `appname_production` | Primary application data |
| `appname_cache_production` | Rails cache store |
| `appname_queue_production` | Solid Queue job storage |
| `appname_cable_production` | Action Cable |
| `appname_rails_pulse_production` | RailsPulse monitoring |

Development and test environments use a primary database plus a separate `rails_pulse` database.

### Authentication & Authorization

- **Devise** — user authentication (sign up, sign in, password reset, etc.)
- **Action Policy** — authorization via declarative policy objects. Keeps authorization logic out of controllers and models.

### Frontend

- **Inertia.js + Vite** — SPA-like experience without a separate API. Rails renders page props server-side; your JS framework (Vue, React, or Svelte — chosen during `inertia:install`) renders the UI client-side.
- **js-routes** — exposes your Rails routes as a JavaScript module, auto-regenerated in development.
- **Typelizer** — generates TypeScript types from your Ruby serializers so your frontend stays in sync with your backend.
- **Alba** — lightweight JSON serialization, used instead of JBuilder.

### Background Jobs (optional)

When you choose to install Solid Queue:

- **Solid Queue** — database-backed job queue, no Redis required.
- **Mission Control** — web dashboard at `/jobs` to inspect and manage queued jobs.
- A separate `workers` role is configured in `config/deploy.yml` so jobs run in their own container alongside the web container on the same server.

### Testing

- **RSpec** — test framework, configured with `spec/support/` auto-loading.
- **Factory Bot** — test data factories. All Factory Bot syntax methods (`create`, `build`, `build_stubbed`) are available in every spec without explicit includes. Put your factories in `spec/factories/`.
- **Faker** — fake data generation for use inside factories.
- **Shoulda Matchers** — one-liner matchers for common Rails validations and associations (`validate_presence_of`, `belong_to`, etc.).

### Code Quality

All of these run automatically, with no configuration required:

| Tool | What it does |
|------|-------------|
| Standard + standard-rails | Ruby linting (Evil Martians style, stricter than default RuboCop) |
| rubocop-rspec | RuboCop cops for RSpec files |
| Prosopite | Detects N+1 queries in development and test (logs warnings) |
| Strong Migrations | Blocks unsafe database migrations at development time |
| Database Consistency | Checks that your DB constraints match your model validations |
| Database Validations | Validates against DB constraints in your models |
| Isolator | Warns about non-atomic operations inside transactions |

RuboCop runs `--autocorrect-all` at the end of template generation so the generated code starts clean.

### Development Dashboards

All available in development after `bin/dev`:

| URL | Tool | Purpose |
|-----|------|---------|
| `http://localhost:3000/rails_pulse` | RailsPulse | Request rate, error rate, performance metrics |
| `http://localhost:3000/pghero` | PgHero | Slow queries, index usage, connection stats |
| `http://localhost:3000/letter_opener` | Letter Opener Web | Browse emails sent by your app |
| `http://localhost:3000/jobs` | Mission Control | Job queue (only if Solid Queue installed) |
| `http://localhost:3001` | Rack Mini Profiler | Per-request profiling badge (appears on every page) |

### Email

- **Letter Opener Web** — all emails sent in development are captured and viewable at `/letter_opener`. No real emails are sent.
- **Premailer** — automatically inlines CSS into email HTML at send time, so your emails render correctly in email clients.

### CI (GitHub Actions)

A `.github/workflows/ci.yml` is generated with two jobs that run on every push and pull request:

**lint** — runs `bundle exec rubocop --parallel`. Fails the build on any Standard violation.

**test** — spins up a PostgreSQL 16 service container, sets up the test databases, and runs `bundle exec rspec`. Uses `ruby/setup-ruby` with Bundler caching for fast runs.

The Ruby version in the workflow matches whatever you entered at the RuboCop prompt.

### Deployment (Kamal)

The template generates a `config/deploy.yml` targeting a single Hetzner server with an external Hetzner Managed PostgreSQL database. The architecture:

```
Hetzner CX21 / CX31
├── web container     (Rails app, kamal-proxy handles SSL)
└── workers container (Solid Queue, if enabled)

Hetzner Managed PostgreSQL (external, ~€15/mo)
└── all 5 databases
```

After generation, three placeholders need to be filled in `config/deploy.yml`:

```yaml
servers:
  web:
    - YOUR_SERVER_IP        # ← your Hetzner server's public IP

proxy:
  host: your-app.example.com  # ← your domain

registry:
  username: your-user          # ← your Docker Hub username
  image: your-user/appname
```

And in `.kamal/secrets`, set your database credentials:

```bash
DB_HOST=$DB_HOST        # Hetzner Managed PostgreSQL host
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
```

These reference shell environment variables — export them in your shell before running any `kamal` commands. Never put raw credentials in this file.

**First deploy:**

```bash
# Provision the server, install Docker, set up SSL, start containers
kamal setup

# Subsequent deploys
kamal deploy
```

**Useful aliases:**

```bash
bin/kamal console   # Rails console on the server
bin/kamal logs      # Tail production logs
bin/kamal shell     # Bash shell inside the container
bin/kamal dbc       # Database console
```

## Claude Code skills

The template automatically installs a curated set of Claude Code skills globally so they're available across all your projects:

| Skill | Source | What it does |
|-------|--------|-------------|
| `inertia-rails-architecture` | inertia-rails/skills | Server vs client state decisions — load this first when building any Inertia feature |
| `inertia-rails-controllers` | inertia-rails/skills | Prop strategies, flash, validation errors, `inertia_location` |
| `inertia-rails-pages` | inertia-rails/skills | Layouts, navigation, infinite scroll, deferred sections |
| `inertia-rails-forms` | inertia-rails/skills | Full form handling, file uploads, multi-step wizards |
| `inertia-rails-typescript` | inertia-rails/skills | `SharedProps`/`InertiaConfig` type augmentation |
| `rails-architecture` | rails_ai_agents | Rails architecture patterns and decisions |
| `postgres-patterns` | rails_ai_agents | PostgreSQL-specific patterns |
| `solid-queue-setup` | rails_ai_agents | Solid Queue configuration |
| `performance-optimization` | rails_ai_agents | N+1 detection, caching, indexing |
| `security-audit` | rails_ai_agents | Security analysis |
| `extraction-timing` | rails_ai_agents | When and how to extract services, concerns, query objects |
| `behavioral-guidelines` | rails_ai_agents | Anti-patterns to avoid |

Skills are installed with `npx skills add … -g` and require [Node.js](https://nodejs.org) / npx to be available. If npx is not found, this step is silently skipped and skills can be installed manually afterward.

## Post-generation checklist

After `rails new` finishes, a summary is printed. The key steps:

- [ ] Set a root route in `config/routes.rb`
- [ ] Add `before_action :authenticate_user!` to `ApplicationController` (if you generated a Devise model)
- [ ] Fill in `config/deploy.yml` (server IP, domain, registry username)
- [ ] Export `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD` in your shell for Kamal
- [ ] Change Mission Control and PgHero passwords before deploying to production
- [ ] Run `bundle exec database_consistency` to verify your schema matches your models

## Conventions

This template makes deliberate choices. If you're adding to the app, follow these:

- **Serializers** — use Alba, not JBuilder. Create serializer classes in `app/serializers/`.
- **Authorization** — use Action Policy. Create policy classes in `app/policies/`.
- **Ruby style** — Standard enforces the style automatically. Run `bundle exec rubocop` to check; `bundle exec rubocop --autocorrect` to fix auto-correctable offenses.
- **Migrations** — Strong Migrations will refuse unsafe operations (adding a non-nullable column, removing a column without ignoring it first, etc.). Follow its guidance or use its helper methods.
- **N+1 queries** — Prosopite logs a warning to the Rails logger whenever an N+1 is detected in development or test. Treat these as errors.

## Extending the template

All setup logic is in `template.rb`. The file is linear: gem declarations at the top, `after_bundle` blocks for configuration. To add a new tool:

1. Add the gem near related gems, using `gem_group` if it's not a production dependency.
2. Add an `after_bundle` block using Rails template helpers (`generate`, `gsub_file`, `append_to_file`, `initializer`, etc.).
3. If the tool needs an app-specific config file, add a `.tt` ERB template under `templates/` and copy it with `template "templates/foo.yml.tt", "config/foo.yml"`.
