# How To: Common Rails Commands

##### A cheatsheet of everyday commands, for someone new to Ruby/Rails on this project.

---

## Start here: the dev loop

| Command | What it does | When |
|---|---|---|
| `bin/dev` | Starts the Rails server **and** the Tailwind watcher together | Your default for running the app locally |
| `bin/rails s` | Starts just the Rails server | Only if you don't need Tailwind rebuilding (rare) |
| `bin/rails c` | Opens an interactive Ruby console with the app loaded | Poke at data, test a method, debug a model |
| `bin/rails c --sandbox` | Console where every DB change rolls back on exit | Experimenting with writes you don't want to keep |

---

## Rails console basics

Once inside `bin/rails c`, this is the 90% you'll use:

| Command | What it does |
|---|---|
| `Model.all` | Every row, as a lazy relation |
| `Model.find(id)` | One row by primary key (raises if missing) |
| `Model.where(column: value)` | A filtered relation |
| `Model.count` | Row count (runs SQL `COUNT`, doesn't load records) |
| `Model.first` / `Model.last` | First/last row by primary key |
| `record.association_name` | Follow an association, e.g. `county.state` |
| `reload!` | Reload app code without restarting the console |
| `exit` | Quit |

---

## Database

| Command | What it does | When |
|---|---|---|
| `bin/rails db:prepare` | Creates the DB if missing, runs pending migrations | Safe default after pulling new migrations |
| `bin/rails db:migrate` | Runs pending migrations only | You know migrations are pending |
| `bin/rails db:rollback` | Undoes the last migration | Fixing a migration you just wrote |
| `bin/rails db:seed` | Runs `db/seeds.rb` | Load reference/sample data |
| `bin/rails db:reset` | **Drops**, recreates, migrates, and seeds the DB | Rare — local DB is corrupted/out of sync. Destructive. |

---

## Testing & linting

| Command | What it does | When |
|---|---|---|
| `bundle exec rspec` | Runs the full test suite | Before opening a PR |
| `bundle exec rspec spec/models/foo_spec.rb` | Runs one file | Iterating on one model/feature |
| `bundle exec rspec spec/models/foo_spec.rb:23` | Runs one example, by line number | Debugging a single failing test |
| `bin/ci` | Runs everything CI runs (lint + specs + more) | Before calling work done — required by [CLAUDE.md](../../CLAUDE.md) |
| `bin/standardrb --fix` | Auto-fixes Ruby style | Before committing `.rb` changes |
| `bin/erb_lint --lint-all --autocorrect` | Auto-fixes ERB template style | Before committing `.html.erb` changes |

Lefthook runs both linters automatically on staged files if you have git hooks installed — see [CONTRIBUTING.md](../../CONTRIBUTING.md).

---

## Generators

| Command | What it creates |
|---|---|
| `bin/rails g model Foo bar:string` | A model, migration, and spec skeleton |
| `bin/rails g migration AddBarToFoos bar:string` | A migration only |
| `bin/rails g controller Foo index show` | A controller, views, and spec skeleton |

Generated code is a starting point, not final — review it against existing conventions before committing.

---

## `bin/x` vs `bundle exec x` vs bare `x`

- **`bin/rails`, `bin/standardrb`, etc.** are binstubs — they already run inside this project's bundle. Prefer these.
- **`bundle exec rspec`** — there's no `bin/rspec` binstub here, so RSpec needs the `bundle exec` prefix to use this project's gem versions instead of whatever's installed globally.
- **Bare `rspec` / `rails`** may happen to work, but can silently run the wrong gem version — avoid it.
