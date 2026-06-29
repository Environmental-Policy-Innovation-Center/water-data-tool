# frozen_string_literal: true

TableColumn = Data.define(
  :key,         # Symbol  — unique id; matches DB/association field name (except :check, :epa_report)
  :label,       # String or nil — <th> label text; nil for non-display columns (e.g. :check)
  :sort,        # String or nil — sort param value; nil means non-sortable
  :format,      # Symbol — :str, :num, :dec, :pct, :cur, :bool, :check, :link
  :format_opts, # Hash   — extra opts passed to format helpers (e.g., { precision: 0 })
  :size,        # Symbol — :default, :sm, :wide, :pinned, :check
  :row_header,  # Boolean — true only for pws_name (renders <th scope="row"> sticky left-7)
  :pinned,      # Boolean — true means always visible regardless of cols= param
  :source,      # Symbol or nil — where cell data lives: :pws = directly on PublicWaterSystem;
  #   any AR association name (e.g. :violations_summary) = traverse that association first;
  #   nil = no model data needed (column renders without reading a value)
  :category,    # Symbol or nil — groups this column under a named category in the column picker
  :csv_label,   # String or nil — verbose CSV column header (intentionally differs from :label)
  :sql_expr     # String or nil — qualified "table.column" for CSV and GeoJSON exports (e.g. "public_water_systems.pwsid"); nil for non-exported columns
)
