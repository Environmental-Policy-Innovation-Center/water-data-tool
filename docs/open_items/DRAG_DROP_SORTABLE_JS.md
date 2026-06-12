# Drag-and-Drop Column Reordering (SortableJS)

## Context

### What
Implement drag-and-drop reordering for both column groups and individual columns within the
manage-columns panel using SortableJS.

### Why
Column order is already persisted in the `cols=` URL param — the infrastructure is in place.
Drag handles are already rendered in `column_row_component.html.erb` (decorative only). This
work wires them up so users can physically reorder columns without relying solely on the
checkbox list.

---

## Implementation Guide

### Setup

Vendor SortableJS via importmap so ECS instances don't depend on an external CDN at runtime:

```bash
bin/importmap pin sortablejs --download
```

### Project-Specific Architecture

This app does **not** use a backend PATCH endpoint for order persistence. Column order lives
entirely in the `cols=` URL param. The SortableJS `onEnd` callback should call
`manage_columns_controller#serializeCols()` and submit the form — not fetch a PATCH endpoint.

### Two Independent Sortable Containers

- **Outer `<ul>`** — category reordering. Each category `<li>` is the drag target.
- **Each `<ul id="cat-body-{key}">`** — column reordering within a category.

Columns should not be draggable between categories — keep each inner list as an isolated
Sortable instance.

### Fix `ColumnRegistry.visible` Key Ordering

For reordered columns to appear in the correct order in the table, `ColumnRegistry.visible`
must respect the key order from the `cols=` param rather than YAML definition order:

```ruby
# current — returns columns in YAML order regardless of param order
pinned + selectable.select { |c| keys.include?(c.key) }

# fix — cols= param is the source of truth for order when present
selectable_by_key = selectable.index_by(&:key)
pinned + keys.filter_map { |k| selectable_by_key[k] }
```

When `keys` is nil (param absent), YAML order is used unchanged. Pinned columns always lead
since they are not user-reorderable.

### Stimulus Controller

```javascript
// app/javascript/controllers/sortable_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  connect() {
    this.sortable = new Sortable(this.element, {
      animation: 150,
      ghostClass: "sortable-ghost",
      onEnd: this.onDragEnd.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) this.sortable.destroy()
  }

  onDragEnd(event) {
    if (event.newIndex === event.oldIndex) return
    // Call serializeCols() and submit the manage-columns form
    // to persist the new order into the cols= URL param
    this.dispatch("reorder")
  }
}
```

---

## Checklist

- [ ] `bin/importmap pin sortablejs --download`
- [ ] Fix `ColumnRegistry.visible` key ordering (see above)
- [ ] Wire outer `<ul>` as Sortable for category reordering
- [ ] Wire each `<ul id="cat-body-{key}">` as isolated Sortable for column reordering
- [ ] Connect `onEnd` → `serializeCols()` → form submit
- [ ] Verify `cols=` param encodes the new order correctly after drag
- [ ] Run `bin/ci` — all specs green

---

> **Cleanup:** Delete this file when drag-and-drop column reordering is shipped. Reference the closing PR in the commit message.
