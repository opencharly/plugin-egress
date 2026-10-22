// Egress schema for the containerd config TOML charly renders — the config the daemon reads at
// /etc/containerd/config.toml. TOML is a non-data text output, so it validates via its structured
// PRE-IMAGE, which is what this types.
//
// TWO config versions are valid, as a union:
//
//   - version 2 — the Firecracker substrate's config (the `plugin` singular pre-image, the CRI
//     plugin's `io.containerd.grpc.v1.cri` snapshotter field). Its consumers still render it, so it
//     is NOT replaced by the v4 arm;
//   - version 4 — the current shape prescribed by CONTAINERD.md §3.1 for the host candies and the
//     pod-crabbox image contract: `plugins` plural, the CRI plugin under
//     `io.containerd.cri.v1.runtime`, and server settings under plugin IDs.
//
// The snapshotter is deliberate rather than left open: it is the one field that decides whether a
// host with NO devmapper device can run pools at all (the device-less case the umbrella ledger
// records), so a config naming a snapshotter this substrate cannot back is a finding, not a
// free-form string.
#ContainerdConfig: #ContainerdConfigV2 | #ContainerdConfigV4

// #ContainerdSnapshotterName is the set of snapshotter IDs this substrate can back — shared by the
// v2 CRI `snapshotter` field and the v4 snapshotter plugin blocks / transfer unpack entries.
#ContainerdSnapshotterName: "native" | "overlayfs" | "devmapper" | "btrfs" | "zfs"

// #ContainerdConfigV2 is the version-2 config the Firecracker path renders.
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
			containerd?: {
				default_runtime_name?: string & !=""
				snapshotter?:          #ContainerdSnapshotterName
				// runtimes — one entry per runtime handler. `runtime_type` is required: a handler
				// without it cannot be constructed, and the crun/krun pair differs only in
				// options.BinaryName.
				runtimes?: [string]: {
					runtime_type!: string & !=""
					pod_annotations?: [...string & !=""]
					options?: {
						BinaryName?:    string & !=""
						SystemdCgroup?: bool
						...
					}
					...
				}
				...
			}
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
