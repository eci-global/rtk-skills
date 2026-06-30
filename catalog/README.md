# RTK Filter Catalog

A shared index of **proven** RTK filters contributed by ECI teams. Niche toolchains (MarkSystems/BBj build output, proprietary SQL runners) have no built-in RTK filter, so their token savings stay at 0% until someone writes one. This catalog is where those filters land once they are proven in a product repo.

## The two-tier model

Filters do **not** start here. They start in a product repo's `.rtk/filters.toml`, iterate fast, and are **promoted** to this catalog only after they survive a real pilot.

| Tier | Location | Owner | When |
|------|----------|-------|------|
| **1. Team filter** | `<product-repo>/.rtk/filters.toml` | The product team | First — author, iterate, prove |
| **2. Shared filter** | `catalog/<team>/filters.toml` | Maintainer review | After ~1 week proven + `rtk verify` passes |

Why two tiers: filters mature fastest where the toolchain runs every day. A central catalog of unproven filters would just be a junk drawer. Promote the ones that earned it.

## How to use a catalog filter

You do **not** install the catalog wholesale. Copy the specific filter block you want into your product repo's `.rtk/filters.toml`:

```bash
# 1. Copy the [filters.<name>] block (and its [[tests.<name>]] cases) from
#    catalog/<team>/filters.toml into your repo's .rtk/filters.toml
# 2. Validate
rtk verify
# 3. Commit, then honor the project-local filters (0.43.x security gate)
git add .rtk/filters.toml && git commit -m "rtk: add <name> filter from catalog"
rtk trust
```

If a same-named project filter shadows a built-in, RTK prints a warning — that is expected when you intentionally override.

## How to contribute (promote) a filter

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for the full workflow. Short version:

1. Author and prove the filter in your product repo's `.rtk/filters.toml` first.
2. After ~1 week of clean runs (`rtk discover` shows it firing, no "RTK ate my output" reports), open a PR to `rtk-skills` adding `catalog/<team>/filters.toml`.
3. Add or update your row in the index below.
4. Maintainer runs the repo gates (`./scripts/validate.sh`, `./scripts/check-parity.sh`, `./scripts/check-links.sh`) and merges.

Every catalog filter **must** ship with inline `[[tests.<name>]]` cases so `rtk verify` can validate it. A filter with no test is a filter that can silently break.

## Filter index

Empty until pilots prove filters. Add one row per promoted filter, grouped by team.

| Filter name | match_command | Team | Source repo / PR | Status | Notes |
|-------------|---------------|------|------------------|--------|-------|
| `bbjunit-parser` | `(^\|/)parser\.py\b\|testing-unit\.sh\|run-tests\.sh` | marksystems | eci-rhc/ms-marksystems #1905 | promoted | BBjUnit parser.py — drop passing methods, keep failures + summary |
| `testing-integration` | `testing-integration\.sh` | marksystems | eci-rhc/ms-marksystems #1905 | promoted | BBj integration runner — compact pass/skip/fail summary |
| `testing-java` | `testing-java\.sh` | marksystems | eci-rhc/ms-marksystems #1905 | promoted | Java JUnit — keep launcher summary + failure details |
| `testing-all` | `testing-all\.sh\|run-all-tests\.sh` | marksystems | eci-rhc/ms-marksystems #1905 | promoted | All-pipelines rollup — keep pipeline table + RESULT line |
| `run-bbj-integration` | `run-bbj-integration\.sh` | marksystems | eci-rhc/ms-marksystems #1905 | promoted | Single BBj integration — keep markers, errors, pass lines |
| `ms-compiler-build` | `(^\|/)main\.py\|all_others\.py\|all_java\.py\|ms-compiler/compiler` | marksystems | eci-rhc/ms-marksystems #1905 | promoted | ms-compiler build — keep phase headers + compile errors |
| `docker-ms-app` | `docker exec ms-app` | marksystems | eci-rhc/ms-marksystems #1905 | promoted | docker exec ms-app — keep errors + test markers, drop BBj noise |
| `bbj-tests` | `BBjUnitTest\.bbj` | marksystems | eci-rhc/ms-marksystems #1905 | promoted | BBjUnitTest.bbj harness — drop passing/ignored per-test lines |

**Status values:** `pilot` (in a product repo, not yet promoted) · `promoted` (merged into this catalog)

## Directory layout

```
catalog/
├── README.md              # this index
├── _template/
│   └── filters.toml       # copy-paste starter (0.43.x schema, with tests)
└── <team>/                # one folder per contributing team, e.g. sql-heavy/
    └── filters.toml       # that team's proven, promoted filters
```

## Safety rule (from the `rtk-operations` skill)

When in doubt, **keep failure-path information and cut success-path verbosity**. A filter that hides a passing test costs nothing; a filter that hides a failing assertion costs trust — and a disabled RTK saves zero tokens.
