// Egress schema for the containerd config TOML charly renders — the config the daemon reads at
// /etc/containerd/config.toml. TOML is a non-data text output, so it validates via its structured
// PRE-IMAGE, which is what this types.
//
// TWO config versions are valid, as a union:
//
//   - version 2 — the Firecracker substrate's arm (the `plugin` singular pre-image, the CRI
//     plugin's `io.containerd.grpc.v1.cri` snapshotter field). This change is ADDITIVE: v4 is a
//     sibling arm, not a replacement, so v2 stays valid and unchanged (R5 removes a legacy path
//     only when a replacement lands);
//   - version 4 — the current shape prescribed by CONTAINERD.md §3.1 for the host candies and the
//     pod-crabbox image contract: `plugins` plural, the CRI plugin under
//     `io.containerd.cri.v1.runtime`, and server settings under plugin IDs.
//
// The snapshotter is deliberate rather than left open: it is the one field that decides whether a
// host with NO devmapper device can run pools at all (the device-less case the umbrella ledger
// records), so a config naming a snapshotter this substrate cannot back is a finding, not a
// free-form string.
//
// EVERY key is typed where the daemon actually READS it, and a key the daemon ignores is an ERROR,
// never a tolerated extra. That is the rule the v4 arm exists for: containerd warns and ignores an
// unknown key, so a config that validates against an inert key silently runs the daemon default.
// Two live examples of that class are rejected here — a top-level `[grpc]` (v4 binds the default
// socket instead) and `io.containerd.cri.v1.runtime.containerd.snapshotter` (v4 reads the
// snapshotter from the CRI images plugin, not the runtime plugin).
#ContainerdConfig: #ContainerdConfigV2 | #ContainerdConfigV4

// #ContainerdSnapshotterName is the set of snapshotter IDs this substrate can back — shared by the
// v2 CRI `snapshotter` field, the v4 CRI images plugin, the per-runtime override and the transfer
// unpack entries.
#ContainerdSnapshotterName: "native" | "overlayfs" | "devmapper" | "btrfs" | "zfs"

// #ContainerdConfigV2 is the version-2 arm — the `plugin` singular shape containerd reads before
// v4. It is retained because this change replaces nothing; the v4 arm is the one it tightens.
#ContainerdConfigV2: close({
	// version! — REQUIRED, and the `!` is load-bearing rather than decoration: a plain `version: 2` is a
	// regular field whose concrete value the SCHEMA supplies during unification, so a document that omits it
	// still validates as concrete. Measured exactly that way: `{root: /var/lib/containerd}` passed until the
	// required marker was added. An optional `version?: 2` would be worse still — it would accept a document
	// with no version at all.
	version!: 2
	root?:    string & !=""
	state?:   string & !=""
	// plugin — the version-2 plugin map. The CRI plugin's own containerd block is where the snapshotter lives.
	plugin?: {
		"io.containerd.grpc.v1.cri"?: {
			containerd?: {
				snapshotter?: #ContainerdSnapshotterName
				...
			}
			...
		}
		...
	}
	// plugins (PLURAL) is the v4 plugin map, and a version-2 daemon IGNORES it whole. The v2 arm
	// is otherwise open because the real v2 surface is large; this one v4-only identifier is
	// bottomed out so a v4 document mislabelled `version: 2` is REJECTED instead of passing with
	// every plugin setting inert.
	plugins?: _|_
	...
})

// #ContainerdConfigV4 is the version-4 config CONTAINERD.md §3.1 prescribes.
//
// The TOP LEVEL is closed with NO `grpc` field, and that omission is the point: in v4 a top-level
// `[grpc]` address is IGNORED by the daemon, which binds its default socket instead. That shape
// cost a real incident (a daemon bound the default socket and replaced a host's system socket), so
// a config carrying it is REJECTED here rather than silently accepted. The address belongs under
// `plugins."io.containerd.server.v1.grpc".address`, which the plugin map below types.
#ContainerdConfigV4: close({
	version!:   4
	root?:      string & !=""
	state?:     string & !=""
	temp?:      string & !=""
	oom_score?: int
	// imports — additional config files whose fields overwrite this one, e.g.
	// ["/etc/containerd/conf.d/*.toml"] for the NVIDIA toolkit's drop-in.
	imports?: [...string & !=""]
	disabled_plugins?: [...string]
	required_plugins?: [...string]

	plugins?: {
		// The CRI runtime plugin. Its blocks are used by k3s; nerdctl selects its runtime per
		// container and does not read `default_runtime_name` (CONTAINERD.md §3.2).
		"io.containerd.cri.v1.runtime"?: {
			cni?: {
				bin_dirs?: [...string & !=""]
				conf_dir?: string & !=""
			}
			// The runtime plugin's `containerd` block is CLOSED: its real surface is exactly the
			// four fields below, and a `snapshotter` here is the #15/#16 trap — containerd v4 has
			// no such field on this plugin and warns `Ignoring unknown key ... key="containerd
			// snapshotter"` while it keeps the images plugin's value. Closing the block makes that
			// false friend an ERROR instead of a passing config with an inert key.
			containerd?: close({
				default_runtime_name?:              string & !=""
				ignore_blockio_not_enabled_errors?: bool
				ignore_rdt_not_enabled_errors?:     bool
				// runtimes — one entry per runtime handler. `runtime_type` is required: a handler
				// without it cannot be constructed, and the crun/krun pair differs only in
				// options.BinaryName. `snapshotter` is a REAL per-runtime override
				// (`Runtime.Snapshotter`), so it belongs here rather than on the block above.
				runtimes?: [string]: {
					runtime_type!: string & !=""
					pod_annotations?: [...string & !=""]
					snapshotter?: #ContainerdSnapshotterName
					options?: {
						BinaryName?:    string & !=""
						SystemdCgroup?: bool
						...
					}
					...
				}
			})
			...
		}

		// The CRI images plugin. In v4 this is where the daemon reads the CRI snapshotter — the
		// field the whole substrate turns on (CONTAINERD.md §3.3.2), so it is typed here against
		// the same substrate-backed set rather than left to the `[string]` catch-all below.
		"io.containerd.cri.v1.images"?: {
			snapshotter?: #ContainerdSnapshotterName
			...
		}

		// The v4 gRPC listener (CONTAINERD-IMAGES.md §1.1). A top-level `[grpc]` is deliberately
		// absent from this arm's closed top level.
		"io.containerd.server.v1.grpc"?: {
			address?:               string & !=""
			uid?:                   int
			gid?:                   int
			max_recv_message_size?: int
			max_send_message_size?: int
		}

		// Snapshotter plugins — `root_path` is the key the store-layout contract depends on; each
		// plugin's remaining surface is tolerated (the upstream plugins add options independently).
		"io.containerd.snapshotter.v1.native"?:    #ContainerdSnapshotterConfig
		"io.containerd.snapshotter.v1.overlayfs"?: #ContainerdSnapshotterConfig
		"io.containerd.snapshotter.v1.btrfs"?:     #ContainerdSnapshotterConfig
		"io.containerd.snapshotter.v1.devmapper"?: #ContainerdSnapshotterConfig
		"io.containerd.snapshotter.v1.zfs"?:       #ContainerdSnapshotterConfig

		// The transfer plugin. Each unpack_config entry names the snapshotter that unpacks a
		// platform, so it is validated against the same substrate-backed set as every other
		// snapshotter field.
		"io.containerd.transfer.v1.local"?: {
			max_concurrent_downloads?:       int
			concurrent_layer_fetch_buffer?:  int
			max_concurrent_uploaded_layers?: int
			check_platform_supported?:       bool
			max_concurrent_unpacks?:         int
			config_path?:                    string & !=""
			unpack_config?: [...{
				platform!:    string & !=""
				snapshotter!: #ContainerdSnapshotterName
				differ?:      string
				config_type?: string
				layer_types?: [...string]
				optional?: bool
			}]
		}

		// Any OTHER plugin ID is tolerated: containerd ships plugins independently of this
		// contract, and the known IDs above are the ones the substrate depends on.
		[string]: {...}
	}
})

// #ContainerdSnapshotterConfig is the common shape of a v4 snapshotter plugin block.
#ContainerdSnapshotterConfig: close({
	root_path?: string & !=""
	...
})
