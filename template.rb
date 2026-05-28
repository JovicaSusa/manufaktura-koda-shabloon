# Rails application template
# Usage: rails new myapp -m path/to/template.rb

source_paths << File.dirname(__FILE__)

@install_solid_queue = yes?("Install Solid Queue for background jobs? [y/n]")

gem "devise"
gem "inertia_rails"
gem "rails_pulse"

if @install_solid_queue
  gem "mission_control-jobs"
  gem "propshaft"
  gem "solid_queue"
end

after_bundle do
  # --- RailsPulse (silent, separate database) ---
  generate "rails_pulse:install", "--database=separate"
  copy_file "templates/database.yml", "config/database.yml", force: true
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

  # --- Inertia Rails + Vite (interactive: framework, TypeScript, Tailwind) ---
  generate "inertia:install"

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

  # --- Finalize ---
  rails_command "db:prepare"

  say "\nTemplate applied. Next steps:"
  say "  • Set root route in config/routes.rb"
  say "  • Add before_action :authenticate_user! to ApplicationController"
  say "  • RailsPulse dashboard: http://localhost:3000/rails_pulse"
  say "  • Start dev servers: bin/dev"
  say "  • Verify Inertia: http://localhost:3100/inertia-example"
  if @install_solid_queue
    say "  • Start job processor: bin/jobs"
    say "  • Mission Control dashboard: http://localhost:3000/jobs"
  end
end
