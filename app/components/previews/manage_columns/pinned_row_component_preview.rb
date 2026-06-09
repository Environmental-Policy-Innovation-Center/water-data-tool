class ManageColumns::PinnedRowComponentPreview < Lookbook::Preview
  # @label Default (always-visible pinned column)
  def default
    col = TableColumn.new(
      key: :pws_name, label: "Water System Name",
      sort: "pws_name", format: :str, format_opts: {}, size: :pinned,
      row_header: true, pinned: true, source: :pws,
      csv_label: "Water System Name", sql_expr: "pws.pws_name", category: nil
    )
    render ManageColumns::PinnedRowComponent.new(col:)
  end
end
