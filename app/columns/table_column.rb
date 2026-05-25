TableColumn = Data.define(
  :key,         # Symbol  — unique id; matches DB/association field name (except :check, :epa_report)
  :label,       # String or nil — <th> label text and CSV header
  :sort,        # String or nil — sort param value; nil means non-sortable
  :format,      # Symbol — :str, :num, :dec, :pct, :cur, :bool, :check, :link
  :format_opts, # Hash   — extra opts passed to format helpers (e.g., { precision: 0 })
  :size,        # Symbol — :default, :sm, :wide, :pinned, :check
  :row_header,  # Boolean — true only for pws_name (renders <th scope="row"> sticky left-7)
  :pinned,      # Boolean — true means always visible regardless of cols= param
  :association  # Symbol or nil — association name on PublicWaterSystem
)
