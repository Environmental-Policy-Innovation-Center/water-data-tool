# Tailwind CSS Style Guide for Rails (v4+)

This guide outlines the standard practices for managing Tailwind CSS (v4) within this Rails application. Follow these rules to keep the styling ecosystem clean, fast, and scalable.

## 🚀 Quick Reference
* **Primary Entrypoint**: `app/assets/tailwind/application.css`
* **Configuration File**: NONE (`tailwind.config.js` is deprecated). Use the `@theme` block in your CSS entrypoint.
* **Development Watcher**: Always boot the app using `bin/dev` to run active asset compilation.

---

## 🏎️ Core Philosophy
* **HTML-First, CSS-Last**: Put styles in your views, not in your stylesheet.
* **No Inline Style Bloat**: Prioritize component co-location over traditional CSS classes.

---

## 📱 Mobile-Friendly Layout Strategy

While this application is primarily optimized for **desktop users**, styles must remain flexible enough to scale down smoothly to mobile devices with minimal code tweaking.

* **Code Mobile-First, Design Desktop-First**: Plan your layout for the desktop grid, but write your Tailwind classes from the smallest screen upward. Unprefixed classes represent the mobile layout; use `md:` or `lg:` prefixes to trigger the full desktop view.
* **Flexbox & Grid Flexibility**: Avoid hardcoded pixel widths (`w-[1200px]`). Use percentage bounds, max-widths, and grids (e.g., `w-full max-w-7xl px-4 lg:px-8`) so containers naturally contract on smaller displays.
* **Responsive Layout Shifts**: Use grid or flex layouts that wrap or stack automatically when screen space shrinks (e.g., `flex flex-col md:flex-row`).
* **Hover States Safeguard**: Always wrap hover effects in a media query variant or standard desktop prefix (`lg:hover:bg-brand-dark`) so touch-screen clicks on mobile do not cause sticky hover artifacts.

### Breakpoint visibility patterns

Tailwind breakpoints are **minimum-width** — the prefix activates at that width and above. This means the two common patterns are opposites:

| Class | Renders on | Hidden on |
|---|---|---|
| `hidden sm:block` | tablets + desktop (640px+) | phones |
| `hidden md:block` | desktop (768px+) | phones + small tablets |
| `sm:hidden` | phones only (< 640px) | tablets + desktop |
| `md:hidden` | phones + small tablets (< 768px) | desktop |

**This app's breakpoints:**
- `sm:` (640px) — sidebar appears; use for mobile/desktop toggle (nav bar, sidebar, mobile footer)
- `md:` (768px) — primary desktop layout threshold; use for layout shifts (flex direction, sticky headers, showing/hiding layout panels)
- `lg:` (1024px) — secondary desktop polish
- `xl:` (1280px) — strictly-desktop-only structural elements (sidebar auto-collapse matches `AUTO_COLLAPSE_BELOW = 1280` in `sidebar_controller.js`)

**JS-controlled visibility:** When JS removes a `hidden` class to show an element, a plain `hidden md:block` pattern will not protect mobile — JS wins. Use `max-md:!hidden` to force the element hidden below `md:` regardless of JS state.

---

## ♿ Accessibility (a11y) Standards

* **Focus States**: Never remove default focus outlines without replacing them. Always pair `focus:outline-none` with clear custom utility classes like `focus-visible:ring-2 focus-visible:ring-brand-primary`.
* **Color Contrast**: Verify that text-to-background color combinations meet WCAG AA standards (minimum 4.5:1 ratio).
* **Screen Reader Utilities**: Use the `sr-only` class to hide elements visually while keeping them readable by screen readers.
* **Motion Reduction**: Respect user system preferences by wrapping transitions and animations in the `motion-safe:` or `motion-reduce:` variants.

---

## 📏 Core Best Practices

### 1. Maintain a Thin Entrypoint
Keep `application.css` clear of messy utility groupings. It should strictly handle core imports and design tokens using the v4 syntax:
```css
@import "tailwindcss";

@theme {
  /* Design System variables go here */
}
```

### 2. Componentize HTML (Not CSS)
Do not create custom CSS classes just to group Tailwind utilities. Deduplicate repetitive markup using Rails-native structures:
* **ViewComponents / Partials**: Use for complex UI elements like buttons, cards, and navigation panels.
* **Helper Methods**: Use Rails helper methods to dynamically construct class strings when dealing with complex conditional states.

### 3. Strict Rules for `@apply`
The `@apply` directive should be a last resort.
* **Do use it for**: Global element resets (e.g., standard styles for `p`, `h1` inside `@layer base`), or targeting un-editable HTML from 3rd-party gems.
* **Do NOT use it for**: Moving long strings of classes out of your HTML just to make the HTML look cleaner. This defeats utility-first optimization.

### 4. Leverage CSS-First Design Tokens
Never add raw hex codes or unique spacing units directly into custom CSS. 
* **Extend the Theme**: To add brand colors, custom fonts, or custom breakpoints, declare them inside the `@theme` block in `application.css` as custom CSS properties (e.g., `--color-brand-primary: #4f46e5;`).

### 5. Management & Structure
* **Purge Native Scaffolds**: Delete any standard Rails-generated `scaffold.css` files to prevent layout overrides and conflicts.
* **Native CSS Imports**: If custom CSS is unavoidable, use native CSS `@import` statements *after* `@import "tailwindcss";`.

---

## 🗺️ Third-Party Styles & Component Overrides (e.g., Mapbox)

When working with heavy client-side libraries like Mapbox, certain layout constraints cannot be handled by inline utilities. Follow these rules to handle overrides without breaking Tailwind v4's architecture:

### 1. The Native Cascade Placement
* Do not place third-party layout overrides inside a `@layer` block. 
* Place them at the absolute bottom of `application.css` so they reliably evaluate last and beat unlayered CDN stylesheet dependencies.

### 2. Double-Class Specificity
* Third-party styles often ship with aggressive specificity. To override them safely without resorting to `!important`, chain multiple classes together matching the vendor components:
  ```css
  /* Chaining two vendor classes beats the library's single-class rule */
  .mapboxgl-ctrl-geocoder.mapboxgl-ctrl {
    border-radius: 20px;
    border: 1px solid var(--color-neutral-400);
  }
  ```

### 3. Browser-Specific Architecture Exceptions
* Complex vendor prefixes (such as Chromium/Safari `::-webkit-scrollbar` variables) cannot be parsed by Tailwind utility generation. Keep these tiny, specific blocks native at the bottom of the main stylesheet file.

---

## 🤖 Special Instructions for AI Agents
When generating or modifying views for this repository:
1. **Never inline custom CSS blocks**: Use valid utility classes.
2. **Apply Mobile-First Prefixes**: Write base styles for mobile layouts first, then append `md:` or `lg:` media prefixes to scale upward for the primary desktop view.
3. **Verify Config Tokens**: Check `app/assets/tailwind/application.css` under the `@theme` directive for custom variables (like `--color-brand-*`) before choosing raw Tailwind default colors.
4. **Enforce Semantic HTML and Focus Rules**: Include appropriate `aria-*` attributes, ensure `sr-only` labels exist on visual-only icon buttons, and always style the `focus-visible:` state.