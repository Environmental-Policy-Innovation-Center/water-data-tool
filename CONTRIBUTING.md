# Contributing

Thank you for your interest in contributing to the Drinking Water Explorer. This project is maintained by [EPIC](https://www.policyinnovation.org/) and contributions are welcome.

---

## Getting Started

1. Fork the repository
2. Follow the [Quick Start](README.md#quick-start) instructions to set up your local environment
3. Create a feature branch from `main`

---

## How to Contribute

### Reporting Bugs

Open a GitHub Issue with:

- Steps to reproduce
- Expected vs. actual behavior
- Browser and OS information
- Screenshots if applicable

### Submitting Changes

1. **Branch naming:** Use descriptive branch names — `feature/add-population-filter`, `fix/tile-cache-invalidation`, `docs/update-schema`
2. **Keep changes focused:** One pull request per feature or fix
3. **Write tests:** All PRs should include relevant specs
4. **Update docs:** If your change affects the API, schema, or architecture, update the corresponding doc in `docs/`

### Pull Request Process

1. Ensure all tests pass: `bundle exec rspec`
2. Write a clear PR description explaining what changed and why
3. Link to any related issues
4. Include screenshots for UI changes
5. Request review from a maintainer

---

## Code Standards

### Ruby

- Follow standard Rails conventions
- Run [Standard](https://github.com/standardrb/standard) before committing: `bin/standardrb` (or `bundle exec standardrb`); auto-fix with `bin/standardrb --fix`. Lefthook runs Standard with `--fix` on staged `.rb` files when hooks are installed.
- Lint ERB templates with [ERB Lint](https://github.com/Shopify/erb-lint): `bin/erb_lint --lint-all`; auto-fix with `bin/erb_lint --lint-all --autocorrect` (or `-a`). Lefthook runs ERB Lint with `--autocorrect` on staged `.html.erb` when hooks are installed. Repo config: `.erb_lint.yml`.
- Use `snake_case` for methods and variables
- Keep controllers thin — business logic belongs in models or concerns

### JavaScript (Stimulus)

- One controller per file in `app/javascript/controllers/`
- Use Stimulus naming conventions (`data-controller`, `data-action`, `data-*-target`)
- Prefer Turbo Frames/Streams over custom JavaScript where possible

### CSS

- Use Tailwind utility classes
- Avoid custom CSS unless Tailwind can't express the style
- All components support dark mode via `dark:` prefixed classes

### Testing

- RSpec for all test types
- FactoryBot for test data
- Shoulda Matchers for model association and validation specs
- Write request specs for controller behavior
- Write model specs for scopes and business logic

---

## Commit Messages

Use conventional commit format:

```
feat: add population density filter
fix: correct tile cache key collision at zoom level 5
docs: update API.md with new filter params
refactor: extract Filterable concern from controller
test: add specs for geographic filtering
```

---

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) Code of Conduct. By participating, you agree to uphold this standard.

---

## Questions?

Open a GitHub Issue or reach out to the EPIC team.
