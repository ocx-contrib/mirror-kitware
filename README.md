# mirror-kitware

OCX mirrors for [Kitware](https://www.kitware.com) tooling. One repository, one
spec directory per package.

| Package | Spec | Publishes to | Announced as |
|---|---|---|---|
| CMake | [`cmake/mirror.yml`](cmake/mirror.yml) | `ghcr.io/ocx-contrib/kitware/cmake` | `ocx.sh/kitware/cmake` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

## Layout

`mirror-base.yml` at the root holds the repo-wide policy every spec inherits
via `extends:`. Note that `extends:` is a **shallow** merge — a spec that sets
a top-level key replaces that block whole.

Platform and container configuration is deliberately **not** in the base. The
test matrix is downstream of the per-package libc measurement (`+libc.glibc` on
a key and dropping the Alpine leg are one decision), so `assets:`, `platforms:`
and the evidence comment behind them live together in the package's own spec.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `cmake/mirror.yml` | hand | `ocx-mirror package pipeline generate ci --repo-root . --spec cmake/mirror.yml` |
| `cmake/tests/smoke.star` | hand | — |
| `cmake/metadata*.json`, `cmake/CATALOG.md`, `logo.*` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

`--repo-root .` is required, not optional. Left unset it defaults to the
deepest directory every `--spec` shares, which for a single spec is that spec's
own parent — `cmake/` — and `mirror-base.yml` then sits outside it (exit 64).

CI fails on drift via `ocx-mirror package pipeline generate ci --check`. If a
generated workflow is wrong, the spec or the renderer template is wrong — fix
it there and regenerate.

> **Known gap.** The generated `verify-generated.yml` drift guard runs that
> `--check` **without** `--repo-root`, so on this repository's shape (one spec
> in a subdirectory plus a root `mirror-base.yml`) it exits 64 rather than
> comparing anything. The renderer template hardcodes the flags
> (`ocx-mirror/src/command/package/pipeline/generate/templates/verify-generated.yml`);
> the fix belongs there, and the guard here goes green once that ships. Nothing
> in this repository can be edited to fix it — hand-editing a generated
> workflow is what the guard exists to catch.

Run `direnv allow` once to put the pinned toolchain on `PATH`; keep the
`:0.5.0-dev` tags in `ocx.toml` floating and let `ocx update` move `ocx.lock`.

## The binaries claim

`cmake/mirror.yml` sets `bin_scan: verify`, so the `binaries` list in each
`metadata*.json` is checked against the extracted bundle on every run: an
executable on the interface surface that the file does not declare fails the
run. That matters here because the set is **platform-asymmetric** — `ccmake`
ships on Linux and macOS but not Windows, and `cmcldeps` only on Windows — so
each platform gets its own metadata file and upstream rearranging its archive
surfaces as a red run rather than silent metadata drift.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index PR from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

Both are inherited from the `ocx-contrib` organisation with visibility ALL.
GHCR pushes use the run's own `GITHUB_TOKEN` — no registry secret needed.

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; see
[`NOTICE.md`](NOTICE.md).
