module HomeHelper
  # Renders a sortable column header link that toggles asc/desc on repeated clicks.
  # Appends ↑/↓ indicator to the label when this column is the active sort.
  def table_sort_link(column, label)
    current_dir = (params[:direction] == "desc") ? "desc" : "asc"
    new_dir = (params[:sort] == column && current_dir == "asc") ? "desc" : "asc"
    url = url_for(request.query_parameters.merge("sort" => column, "direction" => new_dir, "page" => 1))
    indicator = if params[:sort] == column
      (current_dir == "asc") ? " ↑" : " ↓"
    else
      ""
    end
    link_to "#{label}#{indicator}", url, class: "hover:underline focus:outline-none focus:underline"
  end

  # aria-sort attribute value for a sortable <th> — returns nil when column is not sorted.
  def aria_sort(column)
    return unless params[:sort] == column
    (params[:direction] == "desc") ? "descending" : "ascending"
  end

  # Integer with thousands separator, dash for nil.
  def fmt_num(val)
    val.nil? ? "—" : number_with_delimiter(val.to_i)
  end

  # Float with thousands separator and explicit decimal precision, dash for nil.
  def fmt_dec(val, precision: 2)
    val.nil? ? "—" : number_with_precision(val, precision: precision, delimiter: ",")
  end

  # Percentage, dash for nil.
  def fmt_pct(val, precision: 2)
    val.nil? ? "—" : number_to_percentage(val, precision: precision)
  end

  # Currency, dash for nil.
  def fmt_cur(val, precision: 0)
    val.nil? ? "—" : number_to_currency(val, precision: precision)
  end
end
