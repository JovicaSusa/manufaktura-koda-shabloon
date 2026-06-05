# Rails application template
# Usage: rails new myapp -m path/to/template.rb

source_paths << File.dirname(__FILE__)

@install_solid_queue = yes?("Install Solid Queue for background jobs? [y/n]")

gsub_file "Gemfile", /^gem ["']sqlite3["'].*\n/, ""

gem "pg"
gem "devise"
gem "inertia_rails"
gem "rails_pulse"
gem "action_policy"
gem "alba"
gem "alba-inertia"
gem "typelizer"
gem "js-routes"

if @install_solid_queue
  gem "mission_control-jobs"
  gem "propshaft"
  gem "solid_queue"
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
  template "templates/database_pg.yml.tt", "config/database.yml", force: true
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

  # --- Inertia Rails + Vite (interactive: framework, TypeScript, Tailwind) ---
  generate "inertia:install"
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
    PgHero.username = ENV.fetch("PGHERO_USERNAME", "#{pghero_user}")
    PgHero.password = ENV.fetch("PGHERO_PASSWORD", "#{pghero_pass}")
  RUBY

  route 'mount PgHero::Engine, at: "/pghero"'

  if yes?("Set up PgHero query stats tracking? [y/n]")
    generate "pghero:query_stats"
    rails_command "db:migrate"
  end

  # --- Standard + RuboCop (Evil Martians style) ---
  ruby_version = ask("Target Ruby version for RuboCop?", default: "3.3")

  create_file ".rubocop.yml", <<~YAML
    inherit_mode:
      merge:
        - Exclude

    require:
      - standard
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

  # --- GitHub Actions CI ---
  create_file ".github/workflows/ci.yml", <<~YAML
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

  say "\nKamal deployment (config/deploy.yml):"
  say "  • Replace YOUR_SERVER_IP with your Hetzner server IP"
  say "  • Replace your-app.example.com with your domain"
  say "  • Replace your-user with your Docker Hub / ghcr.io username"
  say "  • Set DB_HOST, DB_USERNAME, DB_PASSWORD in your shell and in .kamal/secrets"
  say "  • First deploy: kamal setup"
end
