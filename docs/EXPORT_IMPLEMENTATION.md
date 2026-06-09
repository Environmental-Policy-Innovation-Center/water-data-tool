# Export Implementation Guide

## Overview

Exports are delivered in two phases:

- **Phase 1** — correctness fix: replace the silent 500-row truncation with a POST-based export, removing the cap entirely. Small change, high impact.
- **Phase 2** — async exports: offload large file generation to SolidQueue, store via ActiveStorage, and drive the UX with native Hotwire polling. No custom JS polling loop needed.

Phase 1 must be complete before Phase 2. Each phase is independently shippable.

---

## Phase 1: POST-Based Selected-Row Exports

**Status: Not started.**
**Full implementation steps: [URL_STATE_IMPLEMENTATION.md — Part 2](URL_STATE_IMPLEMENTATION.md#part-2-post-based-export-for-selected-rows)**

### What this fixes

`MAX_PWSID_SELECTION = 500` in `exports_controller.rb` silently truncates any selection over 500 rows. A user selecting 600 rows gets 500 with no warning.

POST body has no practical size limit. The fix removes the cap and changes the ID-based export path from GET (URL params) to POST (request body). Filter-based exports stay as GET — they are small and legitimately bookmarkable.

### Files affected

- `config/routes.rb` — add POST route
- `app/controllers/public_water_systems/exports_controller.rb` — `create` action, remove `MAX_PWSID_SELECTION`
- `app/javascript/controllers/export_controller.js` — POST form submission when IDs are present

### Column ordering (future consideration)

`PublicWaterSystemExporter` has hardcoded `CSV_HEADERS` and row order — it ignores the user's visible column set. When column ordering lands in the UI, the POST body should also accept a `cols` param. The exporter will need to support a dynamic column list at that point.

---

## Phase 2: Async Exports via SolidQueue + Turbo Frame Polling

**Status: Not started. Design is complete — ready to implement.**

### The problem

Synchronous exports hold a Puma thread for the full generation time and give the user no feedback. For large result sets (especially GeoJSON with geometry serialization), this risks load balancer timeouts and blank browser waits.

### Architecture

```
User clicks Export
  → POST /public_water_systems/exports (pwsids[] or filter state)
  → ExportsController#create
      - Creates DataExport record (status: pending)
      - Enqueues PublicWaterSystems::ExportJob (SolidQueue, queue: :exports)
      - Returns turbo_stream: replaces export button area with spinner + polling frame

Turbo Frame polls /public_water_systems/exports/:id every 3s
  → ExportsController#show renders the frame partial based on status:
      pending/processing  →  spinner + <meta http-equiv="refresh" content="3"> (self-polls)
      completed           →  download_trigger Stimulus controller fires window.location.href
      failed              →  error message

ExportJob (SolidQueue)
  - Marks DataExport status: processing
  - Builds scope from stored pwsids or filter params
  - Generates file using existing PublicWaterSystemExporter
  - Writes to Tempfile, attaches to DataExport via ActiveStorage
  - Marks status: completed (or failed + error_message on exception)
  - Tempfile cleaned up in ensure block
```

### Key design decisions

**Always async for ID-based exports.** Rather than a threshold (e.g., "async above N rows"), ID-based exports always go async. The UX is consistent, the code path is simpler, and a brief spinner even for small selections is acceptable. Filter-based exports (no rows selected) can stay synchronous until benchmarks show otherwise.

**Turbo Frame polling — no custom JS.** A `turbo_frame_tag` with `src:` pointing to the show endpoint, combined with `<meta http-equiv="refresh" content="3">` inside the frame when status is pending, is the native Hotwire polling pattern. It requires zero JavaScript beyond the auto-download controller on completion.

**Auto-download on completion.** When the polling frame receives a `completed` response, it renders a small Stimulus controller (`download_trigger_controller`) that fires `window.location.href = signed_url` on `connect()`. The browser handles the file download from there.

**Both CSV and GeoJSON.** `DataExport` stores the requested format. `ExportJob` passes it through to `PublicWaterSystemExporter` — no changes needed to the exporter itself.

**File TTL cleanup.** Generated files should be pruned after a reasonable window (e.g., 1 hour). Implement as a separate `PruneExportsJob` scheduled via SolidQueue recurring tasks, or use ActiveStorage's built-in expiry if configured on the service.

### Migration

```ruby
# db/migrate/XXXXXXXXXXXXXX_create_data_exports.rb
class CreateDataExports < ActiveRecord::Migration[8.1]
  def change
    create_table :data_exports do |t|
      t.string :status, default: "pending", null: false  # pending | processing | completed | failed
      t.string :format, null: false                      # csv | geojson
      t.text :error_message
      t.timestamps
    end
  end
end
```

`DataExport` has an ActiveStorage `has_one_attached :file`. The pwsids or filter params used to generate the export do not need to be stored — they are passed directly to the job at enqueue time.

Verify `rails active_storage:install` has been run and migrations are current before adding this table.

### Model

```ruby
# app/models/data_export.rb
class DataExport < ApplicationRecord
  has_one_attached :file

  STATUSES = %w[pending processing completed failed].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :format, inclusion: { in: %w[csv geojson] }
end
```

### Controller

```ruby
# app/controllers/public_water_systems/exports_controller.rb
module PublicWaterSystems
  class ExportsController < ApplicationController
    # GET — filter-based, synchronous (unchanged from Phase 1)
    def show
      if params[:id]
        # Async status poll — renders turbo frame partial
        @export = DataExport.find(params[:id])
        render partial: "public_water_systems/exports/status_frame"
      else
        scope = PublicWaterSystem.apply_filters(FilterParams.permit(params)).with_details
        deliver_export(PublicWaterSystemExporter.new(scope))
      end
    end

    # POST — ID-based, async
    def create
      format = params[:file_format].presence_in(%w[geojson]) || "csv"
      @export = DataExport.create!(status: "pending", format: format)
      PublicWaterSystems::ExportJob.perform_later(@export.id, export_params[:pwsids].to_a)
      respond_to do |f|
        f.turbo_stream
      end
    end

    private

    def export_params
      params.permit(pwsids: [])
    end

    def deliver_export(exporter)
      if params[:file_format] == "geojson"
        render_geojson_export(exporter)
      else
        render_csv_export(exporter)
      end
    end

    def render_csv_export(exporter)
      send_data exporter.to_csv,
        type: "text/csv",
        disposition: 'attachment; filename="drinking_water_explorer_export.csv"'
    end

    def render_geojson_export(exporter)
      compressed = ActiveSupport::Gzip.compress(exporter.to_geojson.to_json)
      response.headers["Content-Encoding"] = "gzip"
      send_data compressed,
        type: "application/json",
        disposition: 'attachment; filename="export.geojson"'
    end
  end
end
```

### Turbo Stream response (create.turbo_stream.erb)

Replaces the export button area with a spinner + self-polling frame immediately on POST response.

```erb
<%# app/views/public_water_systems/exports/create.turbo_stream.erb %>
<%= turbo_stream.replace "export_button_container" do %>
  <div class="flex items-center gap-3 px-4 py-2 bg-gray-50 border border-gray-200 rounded-md">
    <div class="animate-spin h-4 w-4 rounded-full border-2 border-blue-600 border-t-transparent"></div>
    <%= turbo_frame_tag "export_status",
          src: public_water_system_export_path(@export),
          class: "text-sm text-gray-600" %>
  </div>
<% end %>
```

### Polling frame partial (status_frame)

```erb
<%# app/views/public_water_systems/exports/_status_frame.html.erb %>
<%= turbo_frame_tag "export_status" do %>
  <% if @export.completed? %>
    <div data-controller="download-trigger"
         data-download-trigger-url-value="<%= rails_blob_path(@export.file, disposition: "attachment") %>"
         class="text-green-700 font-medium text-sm">
      Ready — downloading…
    </div>
  <% elsif @export.failed? %>
    <p class="text-red-600 text-sm">Export failed. Please try again.</p>
  <% else %>
    <meta http-equiv="refresh" content="3">
    <span class="text-sm text-gray-500 animate-pulse">Preparing export…</span>
  <% end %>
<% end %>
```

### Auto-download Stimulus controller

Fires `window.location.href` the moment it connects — which happens when the completed frame renders.

```js
// app/javascript/controllers/download_trigger_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    window.location.href = this.urlValue
  }
}
```

Register in `app/javascript/controllers/index.js`.

### ExportJob

```ruby
# app/jobs/public_water_systems/export_job.rb
require "csv"

module PublicWaterSystems
  class ExportJob < ApplicationJob
    queue_as :exports

    def perform(export_id, pwsids)
      export = DataExport.find(export_id)
      export.update!(status: "processing")

      scope = PublicWaterSystem.where(pwsid: pwsids).with_details
      exporter = PublicWaterSystemExporter.new(scope)

      Tempfile.create(["export-#{export_id}", ".#{export.format}"]) do |tmp|
        if export.format == "geojson"
          tmp.write(exporter.to_geojson.to_json)
        else
          tmp.write(exporter.to_csv)
        end
        tmp.flush
        export.file.attach(
          io: File.open(tmp.path),
          filename: "drinking_water_export.#{export.format}",
          content_type: export.format == "geojson" ? "application/json" : "text/csv"
        )
      end

      export.update!(status: "completed")
    rescue => e
      export&.update!(status: "failed", error_message: e.message)
      raise  # re-raise so SolidQueue records the failure
    end
  end
end
```

**Note on memory for very large exports:** The exporter currently uses `@scope.each` with preloaded associations. For exports above ~10,000 rows, watch for memory growth. If benchmarks show an issue, the first step is switching from `preload` to `in_batches(of: 2000)` with per-batch association loading. Do not optimize prematurely — measure first.

### Routes

```ruby
# config/routes.rb
namespace :public_water_systems do
  resources :exports, only: [:show, :create]
end
```

Verify the existing export route shape and adjust to match — the existing `show` route for filter-based exports must be preserved.

### Files affected (Phase 2)

| File | Change |
|---|---|
| `db/migrate/..._create_data_exports.rb` | New migration |
| `app/models/data_export.rb` | New model |
| `app/jobs/public_water_systems/export_job.rb` | New job |
| `app/controllers/public_water_systems/exports_controller.rb` | Add `create`, update `show` for status polling |
| `app/views/public_water_systems/exports/create.turbo_stream.erb` | New — spinner + polling frame |
| `app/views/public_water_systems/exports/_status_frame.html.erb` | New — polling frame partial |
| `app/javascript/controllers/download_trigger_controller.js` | New — auto-download on completion |
| `app/javascript/controllers/index.js` | Register `download_trigger_controller` |
| `config/routes.rb` | Add `create` route |

### Testing checklist

- [ ] POST creates a `DataExport` record with `pending` status
- [ ] Job transitions: `pending` → `processing` → `completed`
- [ ] Job failure sets `failed` + `error_message`, re-raises for SolidQueue
- [ ] Turbo frame polls and resolves without JS errors
- [ ] Auto-download fires on completion
- [ ] Error state renders correctly (no infinite spinner)
- [ ] CSV and GeoJSON both attach and download correctly
- [ ] Tempfile is cleaned up (no leaks in `tmp/`)
- [ ] Filter-based GET export (no rows selected) is unaffected

---

## Related Docs

- [URL_MANAGEMENT.md](URL_MANAGEMENT.md) — decision record for GET vs POST export transport
- [URL_STATE_IMPLEMENTATION.md](URL_STATE_IMPLEMENTATION.md) — Phase 1 implementation steps (POST infrastructure)
