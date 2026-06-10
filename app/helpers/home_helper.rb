module HomeHelper
  BLANK_DISPLAY = "—"

  DATASETS = YAML.safe_load_file(Rails.root.join("config/datasets.yml"))
    .fetch("datasets")
    .map(&:symbolize_keys)
    .freeze

  FILTER_TOOLTIPS = YAML.safe_load_file(Rails.root.join("config/tooltips.yml"))
    .fetch("filter_menus")
    .freeze

  def datasets
    DATASETS
  end

  def filter_tooltips
    FILTER_TOOLTIPS
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

  def render_table_cell(col, pws, row_stripe:)
    sticky_bg = (params[:sort] == Sortable::DEFAULT_SORT_COLUMN) ? "bg-blue-50" : row_stripe

    case col.format
    when :check
      td_check = "sticky left-0 z-10 px-2 py-2 border-b border-gray-100 w-7 min-w-7 max-w-7 text-center md:group-hover:bg-blue-50 transition-colors #{sticky_bg}"
      content_tag(:td, class: td_check) do
        tag.input(type: "checkbox",
          class: "cursor-pointer",
          value: pws.pwsid,
          aria: {label: "Select #{pws.pws_name}"},
          data: {row_selection_target: "row", action: "change->row-selection#toggle"})
      end
    when :link
      content_tag(:td, class: td_classes(col)) do
        url = pws.detailed_facility_report
        if url.present?
          link_to("report", url,
            target: "_blank", rel: "noopener noreferrer",
            class: "text-blue-600 md:hover:underline focus:underline focus:outline-none",
            aria: {label: "EPA facility report for #{pws.pws_name} (opens in new tab)"})
        end
      end
    when :copy
      value = cell_value(pws, col).to_s
      content_tag(:td, class: td_classes(col)) do
        content_tag(:div,
          class: "flex items-center gap-1.5",
          data: {controller: "clipboard", clipboard_text_value: value}) do
          safe_join([
            content_tag(:span, value),
            content_tag(:button,
              safe_join([
                content_tag(:span, icon("copy", classes: "text-gray-400 md:group-hover:text-gray-600 transition-colors"),
                  data: {clipboard_target: "copy"}),
                content_tag(:span, icon("check", classes: "text-green-600"),
                  class: "hidden",
                  data: {clipboard_target: "check"})
              ]),
              type: "button",
              title: "Copy #{col.label}",
              aria: {label: "Copy #{value} to clipboard"},
              class: "opacity-0 md:group-hover:opacity-100 focus-visible:opacity-100 cursor-pointer rounded #{focus_ring_classes}",
              data: {action: "click->clipboard#copy"})
          ])
        end
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
