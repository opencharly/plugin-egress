// Egress schema for the containerd config TOML charly renders — the version-2 config the daemon reads at
// /etc/containerd/config.toml. TOML is a non-data text output, so it validates via its structured PRE-IMAGE,
// which is what this types.
//
// The snapshotter is deliberate rather than left open: it is the one field that decides whether a host with
// NO devmapper device can run pools at all (the device-less case the umbrella ledger records), so a config
// naming a snapshotter this substrate cannot back is a finding, not a free-form string.
#ContainerdConfig: close({
	// version! — REQUIRED, and the `!` is load-bearing rather than decoration: a plain `version: 2` is a
	// regular field whose concrete value the SCHEMA supplies during unification, so a document that omits it
	// still validates as concrete. Measured exactly that way: `{root: /var/lib/containerd}` passed until the
	// required marker was added. An optional `version?: 2` would be worse still — it would accept a document
	// with no version at all.
	version!: 2
	root?:   string & !=""
	state?:  string & !=""
	// plugin — the version-2 plugin map. The CRI plugin's own containerd block is where the snapshotter lives.
	plugin?: {
		"io.containerd.grpc.v1.cri"?: {
			containerd?: {
				snapshotter?: "native" | "overlayfs" | "devmapper" | "btrfs" | "zfs"
				...
			}
			...
		}
		...
	}
	...
})
