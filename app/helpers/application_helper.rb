module ApplicationHelper
  # Color is baked into each SVG; pass classes: for Tailwind sizing (e.g. 'w-5 h-5').
  ICON_CACHE = Hash.new do |h, k|
    h[k] = begin
      File.read(Rails.root.join("app/assets/images/icons/#{k}.svg"))
    rescue Errno::ENOENT
      ""
    end
  end

  def icon(name, classes: nil, aria_hidden: true)
    safe_name = name.to_s.gsub(/[^a-z0-9\-_]/, "")
    svg = ICON_CACHE[safe_name]
    return "".html_safe if svg.empty?
    attrs = []
    attrs << "class=\"#{ERB::Util.html_escape(classes)}\"" if classes
    attrs << 'aria-hidden="true"' if aria_hidden
    replacement = attrs.any? ? "<svg #{attrs.join(" ")}" : "<svg"
    svg.sub("<svg", replacement).html_safe
  end
end
