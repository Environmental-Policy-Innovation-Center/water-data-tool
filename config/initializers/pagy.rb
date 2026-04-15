# Pagy configuration — see https://ddnexus.github.io/pagy/toolbox/configuration/options/
#
# limit_key: use "per_page" to match our API param convention (default is "limit")
# limit: default page size
# max_limit: maximum page size a client may request
Pagy::OPTIONS[:limit_key] = "per_page"
Pagy::OPTIONS[:limit] = 50
Pagy::OPTIONS[:max_limit] = 500

# Freeze to prevent accidental mutation after this point. Note: Rails loads initializers
# alphabetically — any initializer or gem after "p" that sets Pagy::OPTIONS will raise FrozenError.
Pagy::OPTIONS.freeze
