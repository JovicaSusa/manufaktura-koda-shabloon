# Rails application template
# Usage: rails new myapp -m path/to/template.rb

source_paths << File.dirname(__FILE__)

@install_solid_queue = yes?("Install Solid Queue for background jobs? [y/n]")
@inertia_framework  = ask("Which frontend framework?", limited_to: %w[vue react svelte], default: "vue")
@inertia_typescript = yes?("Use TypeScript? [y/n]")
@install_tailwind   = yes?("Install Tailwind CSS? [y/n]")

gsub_file "Gemfile", /^gem ["']sqlite3["'].*\n/, ""
gsub_file "Gemfile", /^gem ["']pg["'].*\n/, ""

# Replace database.yml early so Rails generators that boot the app don't try to load sqlite3
template "templates/database_pg.yml.tt", "config/database.yml", force: true

gem "pg"
gem "devise"
gem "inertia_rails"
gem "vite_rails"
gem "rails_pulse"
gem "action_policy"
gem "alba"
gem "alba-inertia"
gem "typelizer"
gem "js-routes"

if @install_solid_queue
  gem "mission_control-jobs"
end

gem "silencer", require: false
gem "freezolite"

gem "database_validations"
gem "database_consistency", require: false
gem "isolator", require: false
gem "prosopite"
gem "strong_migrations"
gem "pghero"

gem_group :development do
  gem "standard", require: false
  gem "standard-rails", require: false
  gem "rubocop-rspec", require: false
end

gem_group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers", require: false
end

gem "evil-seed", require: false
gem "letter_opener_web"
gem "premailer-rails"

gem "rack-mini-profiler"
gem "stackprof"

gem "bundlebun"

after_bundle do
  # --- RailsPulse (silent, separate database) ---
  generate "rails_pulse:install", "--database=separate"
  route "mount RailsPulse::Engine => \"/rails_pulse\""

  # --- Devise (interactive) ---
  generate "devise:install"

  environment(
    'config.action_mailer.default_url_options = { host: "localhost", port: 3000 }',
    env: "development"
  )

  if yes?("Generate a Devise model? (e.g. User) [y/n]")
    model_name = ask("Model name?", default: "User")
    generate "devise", model_name
  end

  if yes?("Copy Devise views for customization? [y/n]")
    generate "devise:views"
  end

  # --- Action Policy ---
  generate "action_policy:install"

  # --- Alba ---
  initializer "alba.rb", <<~RUBY
    Alba.backend = :active_support
    Alba.inflector = :active_support
  RUBY

  # --- js-routes (middleware for auto-regeneration in development) ---
  generate "js_routes:middleware"
  append_to_file ".gitignore", "\n/app/javascript/routes.js\n/app/javascript/routes.d.ts\n"

  # --- Vite + Inertia Rails ---
  run "bundle exec vite install"
  remove_file "bin/dev"
  inertia_opts = "--framework=#{@inertia_framework}"
  inertia_opts += " --typescript" if @inertia_typescript
  inertia_opts += @install_tailwind ? " --tailwind" : " --no-tailwind"
  generate "inertia:install", inertia_opts
  rake "bun:install"

  # --- Solid Queue + Mission Control ---
  if @install_solid_queue
    rails_command "solid_queue:install"

    mj_user = ask("Mission Control dashboard username?", default: "admin")
    mj_pass = ask("Mission Control dashboard password?", default: "secret")

    initializer "mission_control_jobs.rb", <<~RUBY
      MissionControl::Jobs.http_basic_auth_user = "#{mj_user}"
      MissionControl::Jobs.http_basic_auth_password = "#{mj_pass}"
    RUBY

    route 'mount MissionControl::Jobs::Engine, at: "/jobs"'
  end

  # --- Isolator (detect non-atomic interactions within transactions) ---
  initializer "isolator.rb", <<~RUBY
    unless Rails.env.production?
      require "isolator"
    end
  RUBY

  # --- Prosopite (N+1 query detection) ---
  environment "Prosopite.rails_logger = true", env: "development"

  inject_into_file "app/controllers/application_controller.rb",
    after: "class ApplicationController < ActionController::Base\n" do
<<-RUBY
  around_action :n_plus_one_detection

  def n_plus_one_detection
    Prosopite.scan
    yield
  ensure
    Prosopite.finish
  end

RUBY
  end

  # --- Strong Migrations ---
  initializer "strong_migrations.rb", <<~RUBY
    StrongMigrations.lock_timeout = 10.seconds
    StrongMigrations.statement_timeout = 1.hour
  RUBY

  # --- PgHero (Postgres performance dashboard) ---
  pghero_user = ask("PgHero dashboard username?", default: "admin")
  pghero_pass = ask("PgHero dashboard password?", default: "secret")

  initializer "pghero.rb", <<~RUBY
    Rails.application.config.after_initialize do
      PgHero::HomeController.http_basic_authenticate_with(
        name: ENV.fetch("PGHERO_USERNAME", "#{pghero_user}"),
        password: ENV.fetch("PGHERO_PASSWORD", "#{pghero_pass}")
      )
    end
  RUBY

  route 'mount PgHero::Engine, at: "/pghero"'

  if yes?("Set up PgHero query stats tracking? [y/n]")
    generate "pghero:query_stats"
    rails_command "db:migrate"
  end

  # --- Standard + RuboCop (Evil Martians style) ---
  ruby_version = ask("Target Ruby version for RuboCop?", default: "3.3")

  create_file ".rubocop.yml", <<~YAML, force: true
    inherit_mode:
      merge:
        - Exclude

    require:
      - standard

    plugins:
      - standard-rails
      - rubocop-rspec

    inherit_gem:
      standard: config/base.yml
      standard-rails: config/base.yml

    AllCops:
      NewCops: enable
      SuggestExtensions: false
      TargetRubyVersion: #{ruby_version}
      Exclude:
        - "bin/**/*"
        - "db/schema.rb"
        - "node_modules/**/*"
        - "vendor/**/*"
  YAML

  append_to_file ".gitignore", "\n.rubocop_todo.yml\n"

  # --- RSpec + Factory Bot ---
  generate "rspec:install"

  inject_into_file "spec/rails_helper.rb", after: "require 'rspec/rails'\n" do
    "\nDir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }\n"
  end

  create_file "spec/support/factory_bot.rb", <<~RUBY
    RSpec.configure do |config|
      config.include FactoryBot::Syntax::Methods
    end
  RUBY

  create_file "spec/support/shoulda_matchers.rb", <<~RUBY
    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end
  RUBY

  # --- Evil Seed (anonymized DB dumps for development) ---
  create_file "lib/tasks/evil_seed.rake", <<~RUBY
    namespace :evil_seed do
      desc "Create anonymized partial database dump to tmp/dump.sql"
      task dump: :environment do
        require "evil_seed"
        EvilSeed.configure do |config|
          # config.root("User", "id < ?", 1000) do |root|
          #   root.limit(100)
          #   root.anonymize("email") { |email| Digest::MD5.hexdigest(email) + "@example.com" }
          # end
        end
        EvilSeed.dump("tmp/dump.sql")
        puts "Dump written to tmp/dump.sql"
      end
    end
  RUBY

  # --- Letter Opener Web (browse sent emails in development) ---
  environment "config.action_mailer.delivery_method = :letter_opener", env: "development"
  environment "config.action_mailer.perform_deliveries = true", env: "development"
  route 'mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?'

  # --- Premailer Rails (inline CSS for emails, zero config) ---

  # --- Rack Mini Profiler + Stackprof (performance profiler badge in dev) ---
  initializer "rack_profiler.rb", <<~RUBY
    if Rails.env.development?
      require "rack-mini-profiler"
      Rack::MiniProfiler.config.position = "bottom-right"
      Rack::MiniProfiler.config.start_hidden = false
    end
  RUBY

  # --- Silencer (suppress noisy log entries) ---
  initializer "silencer.rb", <<~RUBY
    require 'silencer/rails/logger'
    Rails.application.configure do
      config.middleware.swap(
        Rails::Rack::Logger, Silencer::Logger, config.log_tags,
        silence: [%r{^/assets/}, %r{^/rails_pulse}]
      )
    end
  RUBY

  # --- Freezolite (frozen string literals at compile time) ---
  inject_into_file "config/application.rb", after: "Bundler.require(*Rails.groups)\n" do
    "require \"freezolite/auto\"\n"
  end

  # --- Kamal (Hetzner single-server deployment) ---
  template "templates/deploy.yml.tt", "config/deploy.yml", force: true

  append_to_file ".kamal/secrets", <<~BASH

    # Hetzner Managed PostgreSQL credentials
    DB_HOST=$DB_HOST
    DB_USERNAME=$DB_USERNAME
    DB_PASSWORD=$DB_PASSWORD
  BASH

  # --- GitHub workflow scaffolding ---
  solid_queue_line = @install_solid_queue ? "\n- Solid Queue + Mission Control (background jobs)" : ""

  create_file "CLAUDE.md", <<~MARKDOWN
    # #{app_name}

    ## Stack
    - Ruby on Rails + PostgreSQL (multi-database: primary, cache, queue, cable, rails_pulse)
    - Inertia.js + Vite + TypeScript (no separate API — server renders props)
    - Devise (auth) · Action Policy (authorization) · Alba (serializers)#{solid_queue_line}

    ## Workflow
    1. Write a spec in `docs/specs/<feature>.md` for non-trivial features
    2. Open a GitHub Issue referencing the spec; add it to the Project board
    3. When coding, reference the issue number and spec file for full context

    ## Key conventions
    - Style: Standard (Evil Martians) — never RuboCop defaults
    - Serializers: Alba only — never JBuilder
    - Authorization: Action Policy (policy objects) — never CanCan/Pundit
    - Avoid N+1: Prosopite middleware is active in development
    - Migrations: Strong Migrations blocks unsafe ops — check before running

    ## Dashboards (development)
    - /rails_pulse   — app monitoring
    - /pghero        — Postgres performance
    - /letter_opener — email preview#{@install_solid_queue ? "\n    - /jobs          — job queue (Solid Queue)" : ""}
  MARKDOWN

  create_file ".github/ISSUE_TEMPLATE/feature.yml", <<~YAML
    name: Feature / Spec
    description: Define a feature or technical specification
    title: "[Feature]: "
    labels: ["feature"]
    body:
      - type: textarea
        id: problem
        attributes:
          label: Problem / Goal
          description: What are we solving or building?
        validations:
          required: true
      - type: textarea
        id: solution
        attributes:
          label: Proposed Solution
          description: High-level approach
      - type: textarea
        id: technical
        attributes:
          label: Technical Notes
          description: Models, routes, components, edge cases
      - type: textarea
        id: acceptance
        attributes:
          label: Acceptance Criteria
          description: "- [ ] item"
  YAML

  create_file ".github/ISSUE_TEMPLATE/bug.yml", <<~YAML
    name: Bug Report
    description: Something is broken
    title: "[Bug]: "
    labels: ["bug"]
    body:
      - type: textarea
        id: description
        attributes:
          label: What happened?
        validations:
          required: true
      - type: textarea
        id: steps
        attributes:
          label: Steps to reproduce
          description: "1. Go to... 2. Click... 3. See error"
        validations:
          required: true
      - type: textarea
        id: expected
        attributes:
          label: Expected behaviour
      - type: textarea
        id: environment
        attributes:
          label: Environment
          description: Ruby version, browser, relevant config
  YAML

  create_file ".github/pull_request_template.md", <<~MARKDOWN
    ## Summary

    ## Related Issue
    Closes #

    ## Changes
    -

    ## Test Plan
    - [ ]
  MARKDOWN

  create_file "docs/specs/.keep", ""

  # --- GitHub Actions CI ---
  create_file ".github/workflows/ci.yml", <<~YAML, force: true
    name: CI

    on:
      push:
        branches: [main]
      pull_request:
        branches: [main]

    jobs:
      lint:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: ruby/setup-ruby@v1
            with:
              ruby-version: "#{ruby_version}"
              bundler-cache: true
          - name: Lint with Standard
            run: bundle exec rubocop --parallel

      test:
        runs-on: ubuntu-latest

        services:
          postgres:
            image: postgres:16
            env:
              POSTGRES_USER: postgres
              POSTGRES_PASSWORD: postgres
            ports: ["5432:5432"]
            options: >-
              --health-cmd="pg_isready"
              --health-interval=10s
              --health-timeout=5s
              --health-retries=3

        env:
          RAILS_ENV: test
          DB_HOST: localhost
          DB_USERNAME: postgres
          DB_PASSWORD: postgres

        steps:
          - uses: actions/checkout@v4
          - uses: ruby/setup-ruby@v1
            with:
              ruby-version: "#{ruby_version}"
              bundler-cache: true
          - uses: oven-sh/setup-bun@v2
          - name: Install JS dependencies
            run: bun install
          - name: Set up databases
            run: bundle exec rails db:create db:schema:load
          - name: Run tests
            run: bundle exec rspec
  YAML

  # --- Pullfrog AI PR reviewer ---
  create_file ".github/workflows/pullfrog.yml", <<~YAML, force: true
    # PULLFROG ACTION — DO NOT EDIT EXCEPT WHERE INDICATED
    name: Pullfrog
    run-name: ${{ inputs.name || github.workflow }}

    on:
      workflow_dispatch:
        inputs:
          prompt:
            type: string
            description: Agent prompt
          name:
            type: string
            description: Run name

    permissions:
      contents: read

    jobs:
      pullfrog:
        runs-on: ubuntu-latest
        permissions:
          id-token: write
          contents: read
          pull-requests: write
        steps:
          - name: Checkout code
            uses: actions/checkout@v4
            with:
              fetch-depth: 1
          - name: Run agent
            uses: pullfrog/pullfrog@v0
            with:
              prompt: ${{ inputs.prompt }}
            env:
              GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  YAML

  create_file ".github/workflows/pr_review.yml", <<~YAML, force: true
    name: PR Review

    on:
      pull_request:
        types: [opened, ready_for_review]

    permissions:
      contents: read
      pull-requests: write

    jobs:
      review:
        runs-on: ubuntu-latest
        if: github.event.pull_request.draft == false
        permissions:
          id-token: write
          contents: read
          pull-requests: write
        steps:
          - name: Checkout code
            uses: actions/checkout@v4
            with:
              fetch-depth: 0
          - name: Review PR
            uses: pullfrog/pullfrog@v0
            with:
              prompt: |
                Review the open pull request for this Ruby on Rails + Inertia.js + Vite application.

                Focus on:
                - Correctness bugs and logic errors
                - Security issues (SQL injection, XSS, mass assignment, missing authorization)
                - N+1 queries or missing eager loading (Prosopite is active — check for patterns it would catch)
                - Missing database indices on foreign keys or frequently queried columns
                - Action Policy violations (missing policy checks, incorrect scope usage)
                - Alba serializer issues (exposing sensitive attributes)
                - Strong Migrations violations (unsafe migration patterns)

                Post your findings as inline review comments on the PR via the GitHub API.
                Be concise — flag real issues only, skip style nits unless they cause bugs.
                If the PR looks good, post a short approving summary comment.
            env:
              GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  YAML

  # --- Finalize ---
  run "bundle exec rubocop --autocorrect-all", capture: false
  rails_command "db:prepare"

  say "\nTemplate applied. Next steps:"
  say "  • Ensure PostgreSQL is running and databases exist: rails db:create"
  say "  • Set root route in config/routes.rb"
  say "  • Add before_action :authenticate_user! to ApplicationController"
  say "  • RailsPulse dashboard: http://localhost:3000/rails_pulse"
  say "  • PgHero dashboard:     http://localhost:3000/pghero"
  say "  • Letter Opener (mail): http://localhost:3000/letter_opener"
  say "  • Start dev servers: bin/dev"
  say "  • Verify Inertia: http://localhost:3100/inertia-example"
  say "  • Check DB/model consistency: bundle exec database_consistency"
  if @install_solid_queue
    say "  • Start job processor: bin/jobs"
    say "  • Mission Control dashboard: http://localhost:3000/jobs"
  end

  say "  • Create a GitHub Project board for task tracking (Issues → Projects)"
  say "  • Pullfrog AI PR reviewer: connect your repo at pullfrog.com — see README for setup"

  say "\nKamal deployment (config/deploy.yml):"
  say "  • Replace YOUR_SERVER_IP with your Hetzner server IP"
  say "  • Replace your-app.example.com with your domain"
  say "  • Replace your-user with your Docker Hub / ghcr.io username"
  say "  • Set DB_HOST, DB_USERNAME, DB_PASSWORD in your shell and in .kamal/secrets"
  say "  • First deploy: kamal setup"

  # --- Claude Code Skills ---
  say "\nInstalling Claude Code skills (global)..."
  skills = %w[
    inertia-rails/skills@inertia-rails-architecture
    inertia-rails/skills@inertia-rails-controllers
    inertia-rails/skills@inertia-rails-pages
    inertia-rails/skills@inertia-rails-forms
    inertia-rails/skills@inertia-rails-typescript
    ThibautBaissac/rails_ai_agents
  ]
  skills.each do |skill|
    run "npx skills add #{skill} -g -y 2>/dev/null || true", capture: false
  end
end
