# Pin npm packages by running ./bin/importmap
# Note: bin/importmap pin <pkg> downloads to vendor/javascript/ but may not write the pin line here — add it manually if missing.
# After adding a pin: restart bin/dev and hard-reload the browser (Cmd+Shift+R). No asset compilation needed.

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "url_state_codec", to: "url_state_codec.js"
pin "filter_state", to: "filter_state.js"
pin "stats_frame", to: "stats_frame.js"
pin "selection_state", to: "selection_state.js"

# Third-party vendor libraries (vendored via bin/importmap pin)
pin "pako" # @2.1.0
