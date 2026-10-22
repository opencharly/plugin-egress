package egress

import (
	"strings"
	"testing"
)

// TestEgressNetfilterRules gates the FORWARD/NAT ruleset charly installs on a Firecracker host. The
// positives are the ruleset a pool actually needs; the negatives are the failures this gate exists for — a
// target that is not a real iptables target, a port that is not a number, and a rule with no chain — each of
// which would otherwise reach iptables and fail there instead of here.
func TestEgressNetfilterRules(t *testing.T) {
	p, err := newProvider()
	if err != nil {
		t.Fatalf("newProvider: %v", err)
	}
	cases := []struct {
		name        string
		in          validateInput
		wantInvalid bool
	}{
		{"good-forward-accept", validateInput{Kind: "netfilter_rules", Label: "rules.yaml", Mode: "bytes", Data: "forward:\n  - chain: FORWARD\n    target: ACCEPT\n    proto: tcp\n    dport: 443\n"}, false},
		{"good-nat-masquerade", validateInput{Kind: "netfilter_rules", Label: "rules.yaml", Mode: "bytes", Data: "nat:\n  - chain: POSTROUTING\n    target: MASQUERADE\n    source: 172.16.0.0/12\n"}, false},
		{"good-empty-ruleset", validateInput{Kind: "netfilter_rules", Label: "rules.yaml", Mode: "bytes", Data: "{}\n"}, false},
		{"unknown-target-rejected", validateInput{Kind: "netfilter_rules", Label: "rules.yaml", Mode: "bytes", Data: "forward:\n  - chain: FORWARD\n    target: ALLOW\n"}, true},
		{"dport-string-rejected", validateInput{Kind: "netfilter_rules", Label: "rules.yaml", Mode: "bytes", Data: "forward:\n  - chain: FORWARD\n    target: ACCEPT\n    dport: \"443\"\n"}, true},
		{"missing-chain-rejected", validateInput{Kind: "netfilter_rules", Label: "rules.yaml", Mode: "bytes", Data: "forward:\n  - target: ACCEPT\n"}, true},
	}
	for _, c := range cases {
		got := p.validate(c.in)
		if c.wantInvalid && got == "" {
			t.Errorf("%s: expected a validation failure, got pass", c.name)
		}
		if !c.wantInvalid && got != "" {
			t.Errorf("%s: expected pass, got failure: %s", c.name, got)
		}
	}
}

// TestEgressContainerdConfig gates the containerd config charly renders, for BOTH config versions the
// schema accepts. The snapshotter is the field this substrate turns on — a host with no devmapper device
// must be able to run pools — so a config naming one this substrate cannot back is rejected here in
// either version, as is a version that is not the integer the arm requires.
//
// The v4 pair matters as much as any positive: the SAME config validates with the gRPC address under
// `plugins."io.containerd.server.v1.grpc"` and is REJECTED with a top-level `grpc` address. In v4 the
// daemon ignores a top-level `[grpc]` and binds its default socket, so accepting that shape would let a
// config silently replace a host's system socket — the incident this arm exists to prevent.
func TestEgressContainerdConfig(t *testing.T) {
	p, err := newProvider()
	if err != nil {
		t.Fatalf("newProvider: %v", err)
	}

	// The CONTAINERD.md §3.1 config, rendered as the structured pre-image the TOML renderer emits.
	const v4ContainerdMD31 = `version: 4
plugins:
  io.containerd.cri.v1.runtime:
    cni:
      bin_dirs:
        - /var/lib/rancher/k3s/data/current/bin
      conf_dir: /var/lib/rancher/k3s/agent/etc/cni/net.d
    containerd:
      default_runtime_name: crun
      runtimes:
        crun:
          runtime_type: io.containerd.runc.v2
          options:
            BinaryName: /usr/bin/crun
            SystemdCgroup: true
        krun:
          runtime_type: io.containerd.runc.v2
          pod_annotations:
            - krun.*
          options:
            BinaryName: /usr/bin/krun
            SystemdCgroup: true
`

	// The v4-specific surface beyond §3.1: imports, the server plugin, the snapshotter plugins and a
	// transfer unpack entry.
	const v4PluginPathGRPC = `version: 4
imports:
  - /etc/containerd/conf.d/*.toml
plugins:
  io.containerd.server.v1.grpc:
    address: /run/containerd/containerd.sock
  io.containerd.snapshotter.v1.overlayfs:
    root_path: /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs
    upperdir_label: true
  io.containerd.snapshotter.v1.btrfs:
    root_path: /var/lib/containerd/io.containerd.snapshotter.v1.btrfs
  io.containerd.transfer.v1.local:
    max_concurrent_downloads: 3
    unpack_config:
      - platform: linux/amd64
        snapshotter: overlayfs
        differ: walking
        layer_types:
          - application/vnd.oci.image.layer.v1.tar+gzip
        optional: true
`

	// The rejection control is DERIVED from the accepted config above, so the pair differs by exactly
	// one block: the v2/v3 top-level `grpc` table that v4 ignores. The assertion keeps the derivation
	// honest — a replacement that silently matched nothing would test the accepted config twice.
	v4TopLevelGRPC := strings.Replace(v4PluginPathGRPC,
		"version: 4\n",
		"version: 4\ngrpc:\n  address: /run/containerd/containerd.sock\n", 1)
	if v4TopLevelGRPC == v4PluginPathGRPC {
		t.Fatal("rejection control was not derived: the grpc block was not inserted")
	}

	cases := []struct {
		name        string
		in          validateInput
		wantInvalid bool
	}{
		{"good-v2-native-snapshotter", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 2\nroot: /var/lib/containerd\nplugin:\n  io.containerd.grpc.v1.cri:\n    containerd:\n      snapshotter: native\n"}, false},
		{"good-v2-minimal", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 2\n"}, false},
		{"v2-devmapper-is-declared", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 2\nplugin:\n  io.containerd.grpc.v1.cri:\n    containerd:\n      snapshotter: devmapper\n"}, false},
		{"v2-unknown-snapshotter-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 2\nplugin:\n  io.containerd.grpc.v1.cri:\n    containerd:\n      snapshotter: vfs\n"}, true},
		{"v2-version-string-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: \"2\"\n"}, true},
		{"missing-version-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "root: /var/lib/containerd\n"}, true},

		{"good-v4-containerd-md-3-1", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: v4ContainerdMD31}, false},
		{"good-v4-plugin-path-grpc", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: v4PluginPathGRPC}, false},
		{"v4-top-level-grpc-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: v4TopLevelGRPC}, true},
		{"v4-version-string-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: \"4\"\n"}, true},
		{"v4-runtime-without-runtime-type-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 4\nplugins:\n  io.containerd.cri.v1.runtime:\n    containerd:\n      runtimes:\n        crun:\n          options:\n            BinaryName: /usr/bin/crun\n"}, true},
		{"v4-unpack-unknown-snapshotter-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 4\nplugins:\n  io.containerd.transfer.v1.local:\n    unpack_config:\n      - platform: linux/amd64\n        snapshotter: vfs\n"}, true},
		// The v4 arm types the plugin IDs the substrate depends on and tolerates any other plugin ID;
		// this case is what keeps that deliberate tolerance from silently becoming a closed map.
		{"good-v4-unknown-plugin-tolerated", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 4\nplugins:\n  io.containerd.monitor.v1.cgroups:\n    no_prometheus: false\n"}, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := p.validate(c.in)
			if c.wantInvalid {
				if got == "" {
					t.Fatal("expected a validation failure, got pass")
				}
				t.Logf("rejected: %s", got)
				return
			}
			if got != "" {
				t.Fatalf("expected pass, got failure: %s", got)
			}
		})
	}
}
