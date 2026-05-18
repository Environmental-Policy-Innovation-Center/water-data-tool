source "https://rubygems.org"

# ------------------------------------------------------------------------------
# Rails Ecosystem — Rails, default `rails new` stack (Hotwire, Propshaft, Solid*), and boot
# ------------------------------------------------------------------------------
gem "rails", "~> 8.1.3"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", "~> 1.24.4", require: false

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails", "~> 2.2.3"

# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft", "~> 1.3.1"

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cable", "~> 3.0.12"
gem "solid_cache", "~> 1.0.10"
gem "solid_queue", "~> 1.4.0"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails", "~> 1.3.4"

# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails", "~> 4.4.0"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails", "~> 2.0.23"

# ------------------------------------------------------------------------------
# Everything else (alphabetical)
# ------------------------------------------------------------------------------

# PostGIS adapter for ActiveRecord [https://github.com/rgeo/activerecord-postgis-adapter]
gem "activerecord-postgis-adapter", "~> 11.1.1"

# CSV parsing (extracted from Ruby stdlib in 3.4)
gem "csv", "~> 3.3.5"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.14.0"

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", "~> 2.11.0", require: false

# Structured, single-line logs (and SQL metadata) instead of verbose multi-line Rails logs — easier to scan in production and in log aggregators [https://github.com/roidrage/lograge]
gem "lograge", "~> 0.14.0"
gem "lograge-sql", "~> 2.6.1"

# Fast JSON parser with streaming/SAX support — used by ETL to process large GeoJSON without OOM
gem "oj", "~> 3.17.0"

# Pagination [https://github.com/ddnexus/pagy]
gem "pagy", "~> 43.5.1"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.6.3"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 7.2.0"

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", "~> 0.1.20", require: false

# ViewComponent — server-rendered UI components [https://viewcomponent.org]
gem "view_component", "~> 4.10.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

group :development, :test do
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", "~> 8.0.4", require: false

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", "~> 0.9.3", require: false

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", "~> 1.11.1", platforms: %i[mri windows], require: "debug/prelude"

  # Load environment variables from .env [https://github.com/bkeepers/dotenv]
  gem "dotenv-rails", "~> 3.2.0"

  gem "factory_bot_rails", "~> 6.5.1"

  gem "pry-byebug", "~> 3.12.0"
  gem "pry-rails", "~> 0.3.11"

  gem "rspec-rails", "~> 8.0.4"
  gem "shoulda-matchers", "~> 7.0.1"
end

group :development do
  # Annotate models with schema comments [https://github.com/drwl/annotaterb]
  gem "annotaterb", "~> 4.22.0", require: false

  # ERB template linting [https://github.com/Shopify/erb-lint]
  gem "erb_lint", "~> 0.9.0", require: false

  # Git hooks manager [https://github.com/evilmartians/lefthook]
  gem "lefthook", "~> 2.1.6", require: false

  # Lookbook — ViewComponent dev preview catalog [https://lookbook.build]
  gem "lookbook", "~> 2.3.14"

  # StandardRB — zero-config Ruby linting [https://github.com/standardrb/standard]
  # `standard` is pulled in by standardrb; do not declare it separately.
  gem "standard-rails", "~> 1.6.0", require: false
  gem "standardrb", "~> 1.0.1", require: false

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console", "~> 4.3.0"
end
