package egress

import "testing"

// TestEgressCrabboxYaml gates the rendered crabbox local-container config the
// config: plan-step verb produces: the typed localContainer surface (noHostname
// etc. must be REAL bools) and a non-empty provider, while tolerating upstream
// field additions (the ... breaks).
func TestEgressCrabboxYaml(t *testing.T) {
	p, err := newProvider()
	if err != nil {
		t.Fatalf("newProvider: %v", err)
	}
	cases := []struct {
		name        string
		in          validateInput
		wantInvalid bool
	}{
		{"good-minimal", validateInput{Kind: "crabbox-yaml", Label: "crabbox.yaml", Mode: "bytes", Data: "provider: local-container\n"}, false},
		{"good-noHostname-bool", validateInput{Kind: "crabbox-yaml", Label: "crabbox.yaml", Mode: "bytes", Data: "provider: local-container\nlocalContainer:\n  noHostname: true\n  network: bridge\n"}, false},
		{"noHostname-string-rejected", validateInput{Kind: "crabbox-yaml", Label: "crabbox.yaml", Mode: "bytes", Data: "provider: local-container\nlocalContainer:\n  noHostname: \"yes\"\n"}, true},
		{"missing-provider", validateInput{Kind: "crabbox-yaml", Label: "crabbox.yaml", Mode: "bytes", Data: "localContainer:\n  noHostname: false\n"}, true},
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