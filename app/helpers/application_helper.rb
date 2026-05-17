module ApplicationHelper
  # Constants are used directly in ViewComponent .rb class bodies (include ApplicationHelper puts them in scope).
  # ERB templates can't resolve bare module constants, so each one that's needed in views has a helper method below.

  # Visible only on keyboard navigation (not mouse). Centralised so a brand color change updates all components.
  FOCUS_RING_CLASSES = "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 " \
    "focus-visible:outline-blue-600 motion-reduce:transition-none".freeze

  FILTER_ROW_CLASSES = "px-[15px] py-1.5 hover:bg-neutral-50 [&_label]:align-middle [&_input]:mr-2 " \
    "[&_input]:inline-block [&_input]:align-middle [&_input:not(.rounded-checkbox)]:size-4".freeze

  # Color is baked into each SVG; pass classes: for Tailwind sizing (e.g. 'w-5 h-5').
  ICON_CACHE = Hash.new do |h, k|
    h[k] = begin
      File.read(Rails.root.join("app/assets/svgs/#{k}.svg"))
    rescue Errno::ENOENT
      ""
    end
  end

  def filter_row_classes = FILTER_ROW_CLASSES

  def external_link_to(text, url, **html_options)
    link_to url, target: "_blank", rel: "noopener noreferrer", title: "Opens in new tab", **html_options do
      safe_join([
        text,
        icon("external-link", classes: "w-3.5 h-3.5 shrink-0"),
        content_tag(:span, "(opens in new tab)", class: "sr-only")
      ])
    end
  end

  def icon(name, classes: nil, aria_hidden: true)
    safe_name = name.to_s.gsub(/[^a-z0-9\-_]/, "")
    svg = ICON_CACHE[safe_name]
    return "".html_safe if svg.empty?
    attrs = []
    attrs << "class=\"#{html_escape(classes)}\"" if classes
    attrs << 'aria-hidden="true"' if aria_hidden
    replacement = attrs.any? ? "<svg #{attrs.join(" ")}" : "<svg"
    svg.sub("<svg", replacement).html_safe
  end
end
