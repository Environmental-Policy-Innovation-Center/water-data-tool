module HomeHelper
  BLANK_DISPLAY = "—"

  RATE_TIER_LABELS = {
    "under_125" => "Most pay under $125",
    "tier_125_249" => "Most pay $125–$249",
    "tier_250_499" => "Most pay $250–$499",
    "tier_500_749" => "Most pay $500–$749",
    "tier_750_999" => "Most pay $750–$999",
    "over_1000" => "Most pay over $1,000",
    "no_information" => "No information"
  }.freeze

  DATASETS = YAML.safe_load_file(Rails.root.join("config/datasets.yml"))
    .fetch("datasets")
    .map(&:symbolize_keys)
    .freeze

  TOOLTIPS = YAML.safe_load_file(Rails.root.join("config/tooltips.yml")).freeze
  FILTER_TOOLTIPS = TOOLTIPS.fetch("filter_menus").freeze
  EXPORTS_TOOLTIPS = TOOLTIPS.fetch("exports").freeze

  # Value ladders for the area / density range-select dropdowns.
  AREA_STEPS = [1, 2, 4, 5, 10, 15, 20, 25, 50, 100, 250, 500].freeze
  DENSITY_STEPS = [1, 10, 20, 50, 100, 250, 500, 1000, 2000, 4000, 8000, 10000].freeze

  # Column display format → slider value format (see slider_format_for).
  SLIDER_FORMAT_BY_DISPLAY = {"cur" => "currency", "pct" => "percent"}.freeze

  # Filter controls that render their own block markup, not <li> rows in the category's <ul>.
  BLOCK_FILTER_CONTROLS = %w[range_select pop_cat place].freeze

  def datasets
    DATASETS
  end

  def filter_tooltips
    FILTER_TOOLTIPS
  end

  def exports_tooltips
    EXPORTS_TOOLTIPS
  end

  # Read the decoded filter blob so the menus render their active state server-side
  # on page load. See docs/open_items/FILTER_SERVER_RENDER.md.
  def filter_state
    @filter_state || {}
  end

  def filter_active?(param)
    filter_state[param.to_s].present?
  end

  def filter_checked?(param, value)
    current = filter_state[param.to_s]
    current.is_a?(Array) ? current.include?(value) : current == value
  end

  def filter_range_value(param_base, bound)
    filter_state["#{param_base}_#{bound}"]
  end

  # Active when a min or max bound is set; the URL omits both at default bounds.
  def range_active?(field)
    filter_range_value(field, :min).present? || filter_range_value(field, :max).present?
  end

  # Aggregate state of a subcat parent's child ranges: `any` drives the open panel/arrow,
  # `all` drives the checkbox. "Some but not all" is the indeterminate case (JS-only).
  def subcat_parent_state(parent_key)
    fields = FilterLayout.placements.select { |p| p.parent == parent_key }.map { |p| p.key.to_s }
    active = fields.count { |field| range_active?(field) }
    {any: active.positive?, all: active == fields.size}
  end

  # Emits the `checked` attribute when the condition holds, nothing otherwise.
  def checked_if(condition)
    "checked" if condition
  end

  # DOM ids for a filter control, derived from its field/parent key (shared with filter_controller.js).
  def filter_checkbox_id(key) = "filter-#{key}"

  def filter_panel_id(key) = "panel-#{key}"

  def filter_min_id(key) = "min-#{key}"

  def filter_max_id(key) = "max-#{key}"

  # A radio/multiselect option id, value-slugged.
  def filter_option_id(param, value)
    "filter-#{param}-#{value.present? ? value.to_s.parameterize : "any"}"
  end

  # A field's widget: its filter `control:` when set, else its `kind`.
  def filter_control_for(field_key)
    field = FieldRegistry.find(field_key)
    (field.filter[:control] || field.filter_kind).to_s
  end

  def category_block?(category)
    first = category[:filters].first
    return false unless first.is_a?(String)
    BLOCK_FILTER_CONTROLS.include?(filter_control_for(first))
  end

  # Slider value format: the histogram bin format, else the column's display format; "count" → none.
  def slider_format_for(field)
    fmt = (field.histogram && field.histogram[:format]) ||
      SLIDER_FORMAT_BY_DISPLAY[field.display && field.display[:format]]
    fmt unless fmt == "count"
  end

  # Place filter: the visible search box shows the saved place name, falling back to the
  # raw geoid (mirrors filter_controller.js restore).
  def place_search_value
    filter_state["place_name"].presence || filter_state["place_geoid"]
  end

  # A radio/multiselect option's checked state: when the param is set, whether it
  # includes this value; when the param is absent, the option's manifest default.
  # (An all-or-none multiselect omits the param, so absent means "all defaults".)
  def filter_option_checked?(param, value, default: false)
    filter_active?(param) ? filter_checked?(param, value) : default
  end

  # The <option>s for one side of a range-select, with the option matching the current
  # filter state (or the no-minimum / no-maximum sentinel, when unset) marked selected.
  def range_select_options(steps:, param:, bound:)
    sentinel = (bound == :min) ? ["No minimum", "0"] : ["No maximum", "999999"]
    numeric = steps.map { |n| [n.to_s, n.to_s] }
    choices = (bound == :min) ? [sentinel] + numeric : numeric + [sentinel]
    options_for_select(choices, filter_range_value(param, bound).presence || sentinel.last)
  end

  def tooltip_icon(text)
    content_tag(:span, class: "relative ml-1 inline-block cursor-default",
      data: {controller: "tooltip", tooltip_text_value: text,
             action: "mouseenter->tooltip#show mouseleave->tooltip#hide"}) do
      icon("info", classes: "h-3.5 w-3.5 inline align-middle")
    end
  end

  def hidden_inputs_for_params(except: [])
    safe_join(
      request.query_parameters.except(*except).flat_map do |k, v|
        if v.is_a?(Array)
          v.map { |item| tag.input(type: "hidden", name: "#{k}[]", value: item) }
        else
          [tag.input(type: "hidden", name: k, value: v)]
        end
      end
    )
  end

  def col_highlight(column)
    (column.present? && params[:sort] == column) ? " bg-blue-100/30" : ""
  end

  def fmt_str(val)
    val.presence || BLANK_DISPLAY
  end

  def fmt_rate_tier(val)
    RATE_TIER_LABELS.fetch(val, BLANK_DISPLAY)
  end

  def fmt_bool(val)
    if val.nil?
      BLANK_DISPLAY
    else
      (val ? "Yes" : "No")
    end
  end

  def fmt_num(val)
    val.nil? ? BLANK_DISPLAY : number_with_delimiter(val.to_i)
  end

  def fmt_dec(val, precision: 2)
    val.nil? ? BLANK_DISPLAY : number_with_precision(val, precision: precision, delimiter: ",")
  end

  def fmt_pct(val, precision: 2)
    val.nil? ? BLANK_DISPLAY : number_to_percentage(val, precision: precision)
  end

  def fmt_cur(val, precision: 0)
    val.nil? ? BLANK_DISPLAY : number_to_currency(val, precision: precision)
  end

  # Only the checkbox and the row-header name cell are sticky (frozen on horizontal scroll). NOTE: a
  # layout-"pinned" column is always shown but NOT sticky — "pinned" controls visibility, not freezing.
  def render_table_cell(col, pws, row_stripe:)
    sticky_bg = (params[:sort] == Sortable::DEFAULT_SORT_COLUMN) ? "bg-blue-50" : row_stripe

    case col.format
    when :check
      td_check = "sticky left-0 z-10 px-2 py-2 border-b border-gray-100 w-7 min-w-7 max-w-7 text-center md:group-hover:bg-blue-50 transition-colors #{sticky_bg}"
      content_tag(:td, class: td_check) do
        tag.input(type: "checkbox",
          class: "cursor-pointer size-4 align-middle",
          value: pws.pwsid,
          aria: {label: "Select #{pws.pws_name}"},
          data: {row_selection_target: "row", action: "change->row-selection#toggle"})
      end
    when :link
      content_tag(:td, class: td_classes(col)) do
        url = pws.detailed_facility_report
        if url.present?
          render(UI::ExternalLinkComponent.new(
            url: url,
            show_icon: false,
            underline: false,
            classes: "text-blue-600 md:hover:underline focus:underline focus:outline-none",
            aria_label: "EPA facility report for #{pws.pws_name}"
          )) { "report" }
        end
      end
    when :copy
      value = cell_value(pws, col).to_s
      content_tag(:td, class: td_classes(col)) do
        content_tag(:button,
          safe_join([
            content_tag(:span, value),
            content_tag(:span, icon("copy", classes: "text-gray-400 group-hover/copy:text-gray-600 transition-colors"),
              data: {clipboard_target: "copy"}),
            content_tag(:span, icon("check", classes: "text-green-600"),
              class: "hidden",
              data: {clipboard_target: "check"})
          ]),
          type: "button",
          title: "Copy #{col.label}",
          aria: {label: "Copy #{value} to clipboard"},
          class: "group/copy flex items-center gap-1.5 cursor-pointer rounded #{focus_ring_classes}",
          data: {controller: "clipboard", clipboard_text_value: value, action: "click->clipboard#copy"})
      end
    else
      value = cell_value(pws, col)
      formatted = format_cell_value(value, col.format, col.format_opts)

      if col.row_header
        td_sticky = "sticky left-7 z-10 font-normal text-left md:group-hover:bg-blue-50 transition-colors px-3 py-2 border-b border-gray-100 overflow-hidden max-w-xs #{sticky_bg}"
        content_tag(:th, formatted, class: td_sticky, scope: "row")
      else
        content_tag(:td, formatted, class: td_classes(col))
      end
    end
  end

  def td_classes(col)
    base = "px-3 py-2 border-b border-gray-100"
    if [:num, :dec, :pct, :cur].include?(col.format)
      "#{base} tabular-nums text-right overflow-hidden#{col_highlight(col.sort)}"
    else
      "#{base} overflow-hidden max-w-48#{col_highlight(col.sort)}"
    end
  end

  def cell_value(pws, col)
    return nil if col.source.nil?
    source = (col.source == :pws) ? pws : pws.public_send(col.source)
    source&.public_send(col.key)
  end

  def format_cell_value(value, format, opts)
    case format
    when :str then fmt_str(value)
    when :bool then fmt_bool(value)
    when :num then fmt_num(value)
    when :dec then fmt_dec(value, **opts)
    when :pct then fmt_pct(value, **opts)
    when :cur then fmt_cur(value, **opts)
    when :rate_tier then fmt_rate_tier(value)
    else fmt_str(value)
    end
  end

  def trend_value(pct)
    return "N/A" unless pct
    return content_tag(:span, "0.0%", class: "text-gray-500") if pct.zero?
    arrow, css, label = (pct > 0) ? ["▲", "text-green-600", "increase"] : ["▼", "text-red-600", "decrease"]
    safe_join([
      number_to_percentage(pct, precision: 1),
      content_tag(:span, arrow, class: "ml-1 #{css}", aria: {label: label})
    ])
  end
end
