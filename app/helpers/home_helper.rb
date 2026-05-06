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

  # Renders a sortable column header link with 3-state cycling: unsorted → asc → desc → unsorted.
  # Icon: stacked ▲▼ triangles, right-aligned; active direction is dark gray, inactive is light gray.
  def table_sort_link(column, label)
    is_sorted = params[:sort] == column
    current_dir = (params[:direction] == "desc") ? "desc" : "asc"

    next_url = if is_sorted && current_dir == "desc"
      url_for(request.query_parameters.except("sort", "direction").merge("page" => 1))
    elsif is_sorted
      url_for(request.query_parameters.merge("sort" => column, "direction" => "desc", "page" => 1))
    else
      url_for(request.query_parameters.merge("sort" => column, "direction" => "asc", "page" => 1))
    end

    up_class = (is_sorted && current_dir == "desc") ? "text-gray-600" : "text-gray-300"
    down_class = (is_sorted && current_dir == "asc") ? "text-gray-600" : "text-gray-300"
    sort_icon = content_tag(:span, class: "inline-flex flex-col leading-none flex-shrink-0") do
      safe_join([
        content_tag(:span, "▲", class: "block text-[8px] leading-none #{up_class}"),
        content_tag(:span, "▼", class: "block text-[8px] leading-none #{down_class}")
      ])
    end

    link_to next_url, class: "flex items-center justify-between gap-2 w-full group focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-400 focus-visible:ring-offset-1 rounded-sm" do
      safe_join([content_tag(:span, label, class: "group-hover:underline"), sort_icon])
    end
  end

  # Subtle semi-transparent tint for the active sort column; row stripe still shows through.
  def col_highlight(column)
    (params[:sort] == column) ? " bg-blue-100/30" : ""
  end

  # aria-sort attribute value for a sortable <th>.
  # Returns "none" when column is sortable but not currently sorted.
  def aria_sort(column)
    return "none" unless params[:sort] == column
    (params[:direction] == "desc") ? "descending" : "ascending"
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
