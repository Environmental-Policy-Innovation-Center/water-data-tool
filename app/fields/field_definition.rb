# One field's manifest record, built by FieldRegistry from each config/fields.yml entry. The
# source/display/filter/histogram blocks stay as hashes; the methods below are derived reads.
FieldDefinition = Data.define(
  :key,       # Symbol — the field name (also the DB column, unless :db_column differs)
  :model,     # Symbol or nil — manifest model key (→ table/AR class); nil for value-less :check
  :table,     # Symbol or nil — derived from model (Model.table_name)
  :db_column, # Symbol or nil — real DB column when it differs from :key (usually nil)
  :source,    # Hash or nil — ETL load (file/header/cast); nil when not ingested here
  :display,   # Hash or nil — table-column config; nil when not shown in the table
  :filter,    # Hash or nil — filter config (kind/param/options/…); nil when not filterable
  :histogram  # Hash or nil — histogram config (format/column); nil when no histogram
) do
  def column = db_column || key
  def table_only? = display.nil?
  def category = display && display[:category]&.to_sym
  def cast = source && source[:cast]&.to_sym
  def filter_kind = filter && filter[:kind]&.to_sym

  # Three columns the app conflates: displayed value, filter target, URL param base.
  def filter_column = (filter && filter[:column]) || column
  def filter_param = (filter && filter[:param_base]) || filter_column
  def sort_param = display && display[:sort]&.to_s
  def histogram_col = (histogram && histogram[:column]&.to_sym) || column

  # "table.column" for CSV/GeoJSON export; nil for value-less columns (not exported).
  def export_sql = table && "#{table}.#{column}"
end
