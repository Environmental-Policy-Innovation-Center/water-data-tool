class ManageColumns::ColumnRowComponentPreview < Lookbook::Preview
  # @label Checked, top-level (no category)
  def checked
    col = build_col(key: :population, label: "Population", category: nil)
    render ManageColumns::ColumnRowComponent.new(col:, checked: true)
  end

  # @label Unchecked, top-level
  def unchecked
    col = build_col(key: :population, label: "Population", category: nil)
    render ManageColumns::ColumnRowComponent.new(col:, checked: false)
  end

  # @label Checked, indented (belongs to a category)
  def indented_checked
    col = build_col(key: :open_violations, label: "Open Violations", category: :violations)
    render ManageColumns::ColumnRowComponent.new(col:, checked: true, indented: true)
  end

  # @label Unchecked, indented
  def indented_unchecked
    col = build_col(key: :open_violations, label: "Open Violations", category: :violations)
    render ManageColumns::ColumnRowComponent.new(col:, checked: false, indented: true)
  end

  private

  def build_col(key:, label:, category:)
    TableColumn.new(
      key:, label:, category:,
      sort: nil, format: :str, format_opts: {}, size: :default,
      row_header: false, pinned: false, read_from: :pws,
      csv_label: nil, sql_expr: nil
    )
  end
end
