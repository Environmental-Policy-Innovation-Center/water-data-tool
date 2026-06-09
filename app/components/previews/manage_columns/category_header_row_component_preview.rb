class ManageColumns::CategoryHeaderRowComponentPreview < Lookbook::Preview
  # @label Default (expanded, with child columns)
  def default
    cat = CategoryDef.new(key: :violations, label: "Violations")
    render ManageColumns::CategoryHeaderRowComponent.new(cat:) do
      tag.li("Column A", class: "px-2 py-1.5 text-sm text-neutral-700")
    end
  end

  # @label Empty category (no children)
  def empty
    cat = CategoryDef.new(key: :financial, label: "Financial")
    render ManageColumns::CategoryHeaderRowComponent.new(cat:)
  end
end
