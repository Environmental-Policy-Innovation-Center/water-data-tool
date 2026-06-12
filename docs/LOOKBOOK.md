# LookBook

[LookBook](https://lookbook.build) is the component preview tool used in this project. It provides
a live, browsable catalog of all ViewComponents with isolated renders and configurable params —
useful for building and reviewing components without needing to navigate to the page they live on.

---

## Accessing LookBook

LookBook is mounted in **development only** and is not exposed in staging or production:

```
http://localhost:3000/lookbook
```

Start the app with `bin/dev` and navigate to that URL. No additional setup is required.

---

## Preview Files

Previews live in `app/components/previews/`, mirroring the component directory structure:

```
app/
├── components/
│   ├── ui/
│   │   └── circle_toggle_component.rb
│   └── previews/
│       └── ui/
│           └── circle_toggle_component_preview.rb   ← preview for CircleToggleComponent
```

Each preview file is a plain Ruby class that inherits from `Lookbook::Preview` and defines
one or more example methods. Each method renders the component with a specific set of props.

### Example

```ruby
# app/components/previews/ui/circle_toggle_component_preview.rb
class Ui::CircleToggleComponentPreview < Lookbook::Preview
  def default
    render Ui::CircleToggleComponent.new(checked: false, label: "Example label")
  end

  def checked
    render Ui::CircleToggleComponent.new(checked: true, label: "Checked state")
  end
end
```

---

## Adding New Previews

1. Create a file in `app/components/previews/` that mirrors the component path.
2. Inherit from `Lookbook::Preview`.
3. Define one method per state or variant you want to preview.
4. Restart `bin/dev` if the preview doesn't appear — LookBook reloads on file changes in most
   cases but occasionally needs a restart on new files.

See the [LookBook documentation](https://lookbook.build/guide/previews/) for advanced usage:
annotations, params, layouts, and notes.
