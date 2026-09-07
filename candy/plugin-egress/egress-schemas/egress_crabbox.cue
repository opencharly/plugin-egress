// Egress schema for the crabbox CLI's local-container config — the
// ~/.config/crabbox/crabbox.yaml a `config:` plan step renders. Types the
// contract of docs/providers/local-container.md (upstream openclaw/crabbox,
// localContainer.* surface). The `...` keep it tolerant of upstream field
// additions while still catching type errors (e.g. `noHostname: "yes"`).
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
	...
}