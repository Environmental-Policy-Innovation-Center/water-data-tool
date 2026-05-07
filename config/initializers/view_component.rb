# Register the previews directory with Lookbook only in development.
# Zeitwerk ignores this directory in all environments (see config/application.rb).
if Rails.env.development?
  Rails.application.config.view_component.previews.paths << Rails.root.join("app/components/previews").to_s
end
