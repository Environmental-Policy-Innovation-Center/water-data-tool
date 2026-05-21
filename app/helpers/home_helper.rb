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

  # Subtle semi-transparent tint for the active sort column; row stripe still shows through.
  def col_highlight(column)
    (params[:sort] == column) ? " bg-blue-100/30" : ""
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
