# Rails application template
# Usage: rails new myapp -m path/to/template.rb

source_paths << File.dirname(__FILE__)

gem "devise"
gem "rails_pulse"

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

  # --- Finalize ---
  rails_command "db:prepare"

  say "\nTemplate applied. Next steps:"
  say "  • Set root route in config/routes.rb"
  say "  • Add before_action :authenticate_user! to ApplicationController"
  say "  • RailsPulse dashboard: http://localhost:3000/rails_pulse"
end
