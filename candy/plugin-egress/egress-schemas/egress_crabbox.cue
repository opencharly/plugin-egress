// Egress schema for the crabbox CLI's user config — the
// ~/.config/crabbox/config.yaml a `config:` plan step renders. Types the
// contract of docs/providers/local-container.md and docs/providers/containerd.md
// (upstream openclaw/crabbox, the localContainer.* and containerd.* surfaces).
// The `...` keep it tolerant of upstream field additions while still catching
// type errors (e.g. `noHostname: "yes"`, `containerd.cpus: "two"`).
#CrabboxYaml: {
	provider: string & !=""
	localContainer?: {
		runtime?:      string
		image?:        string
		user?:         string
		workRoot?:     string
		cpus?:         int & >=0
		memory?:       string
		network?:      string
		dockerSocket?: bool
		noHostname?:   bool
		volumes?:      [...string]
		...
	}
	// The containerd SSH-lease provider's own config block. Keys and defaults are
	// the Go `ContainerdConfig` field tags in opencharly/crabbox
	// internal/cli/config_containerd.go; type errors here are the ones a hand-rolled
	// heredoc ships silently (a quoted int, a bool written as a string).
	containerd?: {
		address?:            string
		sshHost?:            string
		sshUser?:            string
		sshPort?:            string
		sshKey?:             string
		rootless?:           bool
		runtime?:            "crun" | "krun" | "runc"
		runtimePath?:        string
		snapshotter?:        "overlayfs" | "native" | "fuse-overlayfs" | "btrfs"
		namespace?:          string
		image?:              string
		user?:               string
		workRoot?:           string
		network?:            string
		initMode?:           "direct" | "systemd"
		nested?:             "off" | "on"
		stateVolume?:        "auto" | "off"
		gpu?:                "off" | "drm" | "nvidia" | "virtio"
		criu?:               "off" | "on" | "auto" | "in-container"
		cpus?:               int & >=0
		memory?:             string
		seccompProfile?:     string
		krunGpuFlags?:       int & >=0
		krunRamHeadroomMiB?: int & >=0
		krunNestedVirt?:     bool
		krunNetwork?:        "tsi" | "passt"
		krunKernel?:         "stock" | "image"
		nodeAddress?:        string
		...
	}
	...
}
