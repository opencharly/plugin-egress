package egress

import "testing"

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

// TestEgressContainerdConfig gates the version-2 containerd config charly renders. The snapshotter is the
// field this substrate turns on — a host with no devmapper device must be able to run pools — so a config
// naming one this substrate cannot back is rejected here, as is a version that is not the integer 2.
func TestEgressContainerdConfig(t *testing.T) {
	p, err := newProvider()
	if err != nil {
		t.Fatalf("newProvider: %v", err)
	}
	cases := []struct {
		name        string
		in          validateInput
		wantInvalid bool
	}{
		{"good-native-snapshotter", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 2\nroot: /var/lib/containerd\nplugin:\n  io.containerd.grpc.v1.cri:\n    containerd:\n      snapshotter: native\n"}, false},
		{"good-minimal", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 2\n"}, false},
		{"devmapper-is-declared", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 2\nplugin:\n  io.containerd.grpc.v1.cri:\n    containerd:\n      snapshotter: devmapper\n"}, false},
		{"unknown-snapshotter-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: 2\nplugin:\n  io.containerd.grpc.v1.cri:\n    containerd:\n      snapshotter: vfs\n"}, true},
		{"version-string-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "version: \"2\"\n"}, true},
		{"missing-version-rejected", validateInput{Kind: "containerd_config", Label: "config.toml", Mode: "bytes", Data: "root: /var/lib/containerd\n"}, true},
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
