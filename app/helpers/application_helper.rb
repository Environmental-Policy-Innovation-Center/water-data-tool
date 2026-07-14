module ApplicationHelper
  # Constants are used directly in ViewComponent .rb class bodies (include ApplicationHelper puts them in scope).
  # ERB templates can't resolve bare module constants, so each one that's needed in views has a helper method below.

  # Visible only on keyboard navigation (not mouse). Centralised so a brand color change updates all components.
  FOCUS_RING_CLASSES = "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 " \
    "focus-visible:outline-blue-600 motion-reduce:transition-none".freeze

  FILTER_ROW_CLASSES = "px-[15px] py-1.5 [@media(hover:hover)]:hover:bg-neutral-50 [&_label]:align-middle [&_label]:text-sm [&_label]:text-neutral-700 [&_input:not([type=text])]:mr-2 " \
    "[&_input:not([type=text])]:inline-block [&_input:not([type=text])]:align-middle [&_input:not(.rounded-checkbox):not([type=text])]:size-4 " \
    "[&_input[type=radio]]:appearance-none [&_input[type=radio]]:rounded-full [&_input[type=radio]]:border [&_input[type=radio]]:border-neutral-700 " \
    "[&_input[type=radio]]:cursor-pointer [&_input[type=radio]:checked]:bg-blue-500 [&_input[type=radio]:checked]:shadow-[inset_0_0_0_3px_white]".freeze

  FILTER_INFO_BUTTON_CLASSES = "ml-1 text-neutral-400 [@media(hover:hover)]:hover:text-neutral-600".freeze

  FILTER_CHECKBOX_CLASSES = "toggle mt-0.5 shrink-0".freeze

  COLLAPSE_TOGGLE_ICON_CLASSES = "size-3.5 shrink-0 -rotate-90 text-neutral-700 transition-transform duration-150".freeze

  DOWNLOAD_STATES = [
    %w[AL Alabama], %w[AK Alaska], %w[AZ Arizona], %w[AR Arkansas],
    %w[CA California], %w[CO Colorado], %w[CT Connecticut], %w[DE Delaware],
    %w[DC District\ of\ Columbia], %w[FL Florida], %w[GA Georgia], %w[GU Guam],
    %w[HI Hawaii], %w[ID Idaho], %w[IL Illinois], %w[IN Indiana],
    %w[IA Iowa], %w[KS Kansas], %w[KY Kentucky], %w[LA Louisiana],
    %w[ME Maine], %w[MD Maryland], %w[MA Massachusetts], %w[MI Michigan],
    %w[MN Minnesota], %w[MS Mississippi], %w[MO Missouri], %w[MT Montana],
    %w[NE Nebraska], %w[NV Nevada], %w[NH New\ Hampshire], %w[NJ New\ Jersey],
    %w[NM New\ Mexico], %w[NY New\ York], %w[NC North\ Carolina], %w[ND North\ Dakota],
    %w[MP Northern\ Mariana\ Islands], %w[OH Ohio], %w[OK Oklahoma], %w[OR Oregon],
    %w[PA Pennsylvania], %w[PR Puerto\ Rico], %w[RI Rhode\ Island], %w[SC South\ Carolina],
    %w[SD South\ Dakota], %w[TN Tennessee], %w[TX Texas], %w[UT Utah],
    %w[VT Vermont], %w[VA Virginia], %w[WA Washington], %w[WV West\ Virginia],
    %w[WI Wisconsin], %w[WY Wyoming]
  ].freeze

  # Color is baked into each SVG; pass classes: for Tailwind sizing (e.g. 'w-5 h-5').
  ICON_CACHE = Hash.new do |h, k|
    h[k] = begin
      File.read(Rails.root.join("app/assets/svgs/#{k}.svg"))
    rescue Errno::ENOENT
      ""
    end
  end

  # The chevron defaults to -rotate-90 (collapsed); drop it to render the expanded state.
  def collapse_toggle_icon_classes(expanded: false)
    expanded ? COLLAPSE_TOGGLE_ICON_CLASSES.sub(" -rotate-90", "") : COLLAPSE_TOGGLE_ICON_CLASSES
  end

  def download_states = DOWNLOAD_STATES
  def filter_checkbox_classes = FILTER_CHECKBOX_CLASSES
  def filter_info_button_classes = FILTER_INFO_BUTTON_CLASSES
  def filter_row_classes = FILTER_ROW_CLASSES
  def focus_ring_classes = FOCUS_RING_CLASSES

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
