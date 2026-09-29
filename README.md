# plugin-egress

Gate the config artifacts charly writes to a system against a CUE schema
**before** the bytes hit disk — the `egress:` validation plugin (`verb:egress`).

The plugin is the egress counterpart to charly's ingress validation: it owns the
validation logic and the egress CUE schemas (including the vendored
cloud-config). charly's in-core `ValidateEgress*` functions are a thin shim that
invokes this plugin's `OpValidate`. It is **compiled-in** — the build/deploy hot
paths call it many times.

## What it provides

| Capability | Surface |
|---|---|
| `verb:egress` | validate an egress artifact against its kind's CUE schema before the write |

## The verb

`verb:egress` is invoked with a `{kind, data, label, mode}` envelope (the
rendered artifact plus the kind it must validate against), not an authored
`plugin_input`. `mode` selects the validation form: `bytes` (serialized YAML/JSON,
the default), `text` (a rendered non-data string), or `xml` (koala-decoded,
best-effort).

| Kind | Validates |
|---|---|
| `rendered_text` | rendered non-data strings (rejects the `<no value>` template marker) |
| `traefik_routes` | traefik dynamic route config |
| `k8s_object`, `kustomization`, `kind_cluster` | kubernetes manifests + kustomization + kind cluster |
| `deploy_record`, `candy_record` | install-ledger records |
| `cloud_init_meta`, `cloud_init_net` | cloud-init meta-data + network-config |
| `libvirt_domain_xml` | the libvirt domain XML |
| `crabbox-yaml` | the crabbox YAML |
| `cloud_config` | the vendored cloud-config schema |

The egress schemas are held **internally** (embedded and compiled in the
plugin's own CUE context); `Describe` ships only a trivial schema to satisfy the
host's plugin-schema gate, so the vendored package never joins the single-blob
`Describe` concat.

## How to use it

`verb:egress` is an internal host contract, not an authorable step: compose the
plugin candy in a project that needs egress validation:

```yaml
- '@github.com/opencharly/plugin-egress/candy/plugin-egress:<tag>'
```

## Layout

- `candy/plugin-egress/` — the plugin module: `main.go` (provider +
  `NewProvider()`/`NewMeta()` + the compiled schema map), `schema/egress.cue`
  (the served declaration surface), `egress-schemas/` (the internal validation
  schemas + the vendored cloud-config), `testdata/` (golden files),
  `cmd/serve/main.go`.
- `charly.yml` — the root project manifest (`discover: candy`).
- `.github/workflows/tag-on-merge.yml` — CalVer tag + `CHANGELOG/` on merge.

## Related

- Owning skill: `/charly-internals:egress` — the egress validation reference.
  This candy carries no `skill:` entity of its own; the gap is tracked in
  [opencharly/opencharly#291](https://github.com/opencharly/opencharly/issues/291).
- `/charly-internals:plugin` — the plugin/provider model.
- [`opencharly/charly`](https://github.com/opencharly/charly) — the charly CLI.
