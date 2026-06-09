# Rails 8.1 Drag-and-Drop Implementation Guide (SortableJS)

This monolithic blueprint covers the terminal configuration, the unified Javascript/HTML architecture, and how to optionally vendor local copies of standard Ruby gems.

---

## Part 1: JavaScript Library Vendoring & Code Setup

Run this terminal command to download SortableJS directly into your local `vendor/javascript/` directory and configure your importmap automatically:

```bash
bin/importmap pin sortablejs --download
```

### The Code Files

Below are the complete, ready-to-use contents for your JavaScript controller, HTML view template, and backend Rails controller.

#### 1. Stimulus Controller File
**Path:** `app/javascript/controllers/sortable_controller.js`
```javascript
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = new Sortable(this.element, {
      animation: 150,
      ghostClass: "sortable-ghost", // CSS class applied to the moving placeholder
      onEnd: this.onDragEnd.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) this.sortable.destroy()
  }

  async onDragEnd(event) {
    if (event.newIndex === event.oldIndex) return

    const itemIds = this.sortable.toArray()

    await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ positions: itemIds })
    })
  }
}
```

#### 2. HTML View File
**Path:** `app/views/items/index.html.erb`
```html
<ul data-controller="sortable" data-sortable-url-value="<%= sort_items_path %>">
  <% @items.each do |item| %>
    <!-- SortableJS uses data-id to build the final sorted array -->
    <li data-id="<%= item.id %>" style="cursor: grab; padding: 10px; border-bottom: 1px solid #ccc;">
      <%= item.name %>
    </li>
  <% end %>
</ul>
```

#### 3. Rails Controller Action File
**Path:** `app/controllers/items_controller.rb`
```ruby
class ItemsController < ApplicationController
  # PATCH /items/sort
  def sort
    # Expects positions params array like: [ "5", "2", "8" ]
    params[:positions].each_with_index do |id, index|
      Item.where(id: id).update_all(position: index + 1)
    end

    head :ok
  end
end
```

---

## Part 2: Appendix - Vendoring Ruby Gems on AWS ECS

Just as you vendored SortableJS to isolate your ECS instances from external network dependencies during client page loads, you can vendor your Ruby backend dependencies. This downloads all `.gem` files into your repository, protecting your builds from potential downtime if RubyGems.org ever goes offline.

### Step-by-Step Ruby Gem Vendoring

#### 1. Configure Bundler to Vendor Locally
Run this command in your development environment root:
```bash
bundle config set --local cache_all true
```

#### 2. Cache Existing Gems
Execute the bundler package command to download every gem binary specified in your `Gemfile` into your application structure:
```bash
bundle package
```
*This places all physical raw gem files inside a newly created folder at `vendor/cache/`.*

#### 3. Commit the Gems to Git
Track the local files inside your repository so they deploy directly with your code:
```bash
git add vendor/cache/
git commit -m "Vendor application Ruby gems locally"
```

#### 4. Update Your Dockerfile for ECS Production Builds
Modify your production deployment `Dockerfile` to ensure Bundler references the internal cached folder exclusively, preventing it from making external network calls during image generation:

```dockerfile
# Inside your production Rails Dockerfile image assembly stage
RUN bundle config set --local deployment 'true' \
    && bundle config set --local without 'development test' \
    && bundle install --local
```
*(The `--local` flag forces Bundler to pull strictly from `vendor/cache/` instead of reaching out to the internet).*
