# AGENTS.md — plugin-egress

Standalone plugin repo for the `egress` capability (`verb:egress`). The plugin is
a Go module at `candy/plugin-egress/` (module path
`github.com/opencharly/plugin-egress/candy/plugin-egress`); the root `charly.yml`
only declares `discover: candy` so the repo is a project and its candy is
scanned.

Canonical files:

- `candy/plugin-egress/charly.yml` — the `plugin-egress:` candy entity
  (`plugin:` block, `plan:` check).
- `candy/plugin-egress/main.go` — the provider (`NewProvider()` + `NewMeta()`)
  and the compiled `kindDefPaths` schema map.
- `candy/plugin-egress/schema/egress.cue` — the served declaration surface.
- `candy/plugin-egress/egress-schemas/` — the internal validation schemas
  (incl. the vendored `cloud_config`).
- `.github/workflows/tag-on-merge.yml` — CalVer tag + `CHANGELOG/` on merge.
- `README.md` — user overview only; never agent guidance.

## Load these skills first (R0)

- `/charly-internals:plugin` — the plugin authoring reference: the `plugin:`
  block, the unified Provider model, the per-plugin CUE-schema contract,
  placement. Load before touching the provider or schema.
- `/charly-internals:egress` — the egress validation reference (the schemas,
  `ValidateEgress`, and the write-before-disk contract).
- `/charly-internals:git-workflow` — before any git/PR action.

## Build / validate / test

- `go build ./...` in `candy/plugin-egress/` — compile the plugin module.
- `go test ./...` in `candy/plugin-egress/` — the plugin's Go tests
  (`egress_test.go`, `crabbox_egress_test.go`, `schema_serve_test.go`,
  `schema_splice_test.go`).
- `charly box validate` at the repo root — the structural check (the candy +
  `plugin:` block, CUE schema).
- The merge gate is the **org-wide** `charly/pr-validator` (required check
  `validate / validate`, defined in `opencharly/.github`); this repo has **no**
  per-repo candy gate.

## Modify this repo

- Edit the `plugin-egress:` candy entity, the Go source, and the CUE schemas
  **together**. The `schema/egress.cue` is the served declaration surface; the
  internal validation schemas live under `egress-schemas/` and are compiled into
  the provider.
- This plugin is **compiled-in** (the build/deploy hot paths invoke it); do not
  describe it as an out-of-process-only plugin.

## Landing

- PR-only. Every change lands through a pull request; the org-required
  `charly/pr-validator` validates the diff and body and arms native auto-merge on
  PASS. Direct pushes to `main` are blocked.
- History lives in `CHANGELOG/` (written by `tag-on-merge` at merge time); the PR
  body IS the changelog.
- The authoritative rulebook is the umbrella `AGENTS.md` in
  `opencharly/opencharly` and `charly/AGENTS.md` in the charly repo. Do not
  restate its rules here.
