class UI::TableHeaderComponent < ViewComponent::Base
  SIZES = {
    default: "sticky top-0 z-20 bg-gray-100 border-b border-gray-200 px-3 py-2 font-medium text-left whitespace-nowrap min-w-[10rem]",
    sm: "sticky top-0 z-20 bg-gray-100 border-b border-gray-200 px-3 py-2 font-medium text-left whitespace-nowrap min-w-[8rem]",
    wide: "sticky top-0 z-20 bg-gray-100 border-b border-gray-200 px-3 py-2 font-medium text-left whitespace-nowrap min-w-[14rem]",
    pinned: "sticky left-7 top-0 z-30 bg-gray-100 border-b border-gray-200 px-3 py-2 font-medium text-left whitespace-nowrap min-w-[12rem]",
    check: "sticky left-0 top-0 z-30 bg-gray-100 border-b border-gray-200 px-2 py-2 w-7 min-w-7 max-w-7 text-center"
  }.freeze

  def initialize(label: nil, column: nil, size: :default)
    @label = label
    @column = column
    @size = size
  end

  def th_classes
    SIZES.fetch(@size) { raise ArgumentError, "Unknown size #{@size.inspect}. Valid: #{SIZES.keys.join(", ")}" }
  end

  def sortable?
    @column.present?
  end

  def check?
    @size == :check
  end

  def aria_sort_value
    return "none" unless helpers.params[:sort] == @column
    (helpers.params[:direction] == "desc") ? "descending" : "ascending"
  end

  def next_sort_url
    query = helpers.request.query_parameters
    is_sorted = query["sort"] == @column

    new_query = if is_sorted && query["direction"] == "desc"
      query.except("sort", "direction").merge("page" => 1)
    elsif is_sorted
      query.merge("sort" => @column, "direction" => "desc", "page" => 1)
    else
      query.merge("sort" => @column, "direction" => "asc", "page" => 1)
    end

    "#{helpers.request.path}?#{new_query.to_h.to_query}"
  end

  def sort_up_class
    (helpers.params[:sort] == @column && helpers.params[:direction] == "desc") ? "text-gray-600" : "text-gray-300"
  end

  def sort_down_class
    (helpers.params[:sort] == @column && helpers.params[:direction] != "desc") ? "text-gray-600" : "text-gray-300"
  end
end
