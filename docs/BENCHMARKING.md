# Performance Benchmarks

Optional local scripts for checking server-side query and map-tile performance.

**None of these run in CI.** `bin/ci` is the deterministic *correctness* gate — it does not measure performance. (If `bin/ci` itself fails, see [how_to/FIX_BIN_CI_CHECK_FAILURES.md](how_to/FIX_BIN_CI_CHECK_FAILURES.md).)

**When to run them:** only when a change could affect performance — spatial SQL, map tiles, query paths, indexes, or cache behavior — and you want to confirm it didn't regress. They're most meaningful after loading a large dataset locally (e.g. the full national ETL import), since they measure at scale.

---

## The scripts

All three are Rails runner scripts:

| Script | Run with | Purpose | Cache behavior |
|---|---|---|---|
| `bin/benchmark` | `bin/rails runner bin/benchmark` | Broad query benchmarking — filters, stats, table loads, search, and warm tile retrieval by zoom tier. Prints to stdout and saves to `tmp/benchmarks/<timestamp>.txt`. | Non-destructive |
| `bin/benchmark-tiles` | `bin/rails runner bin/benchmark-tiles` | The routine tile-SQL regression guard, at overview, state-selection, and system-browsing zooms. | Non-destructive — cold samples call `TileGenerator.generate_layer!` directly and never read, clear, or mutate `tile_cache`. |
| `bin/benchmark-cold` | `bin/rails runner bin/benchmark-cold` | Manual cold-cache investigation of full tile generation. | **Destructive — deletes ALL rows from `tile_cache` before measuring.** |

## Which one to use

- **A tile change** → `bin/benchmark-tiles`. Safe, never touches the cache, quick — this is the routine guard.
- **A query / schema / index change** → `bin/benchmark`, to time the server-side query paths.
- **Deliberate cold-cache investigation** → `bin/benchmark-cold`, only when you specifically want to measure generation from an empty cache.

## After running `bin/benchmark-cold`

It empties the tile cache, so rebuild it afterward — otherwise the app regenerates tiles on demand (slow first views):

```bash
bin/rails runner "TileCacheWarmJob.perform_now"
```

This blocks the terminal until every z0–z8 tile is regenerated — **~30 minutes at national scale**. Progress is logged to stdout.

See the [tile cache section of the README](../README.md#background-jobs-and-tile-cache-refresh) for how tile caching and refresh work.
