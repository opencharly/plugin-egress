// Egress schema for the kind Cluster config charly GENERATES for a
// `target: kindcluster` deploy (the `kind create cluster --config` argument).
// It validates charly's OWN typed-Go output, so it checks STRUCTURE — the real
// egress failure mode (a missing/empty kind or apiVersion, an empty nodes list,
// a node with no role) — rather than deep per-field kind types. Open beyond the
// envelope (`...`) because kind's Cluster spec varies widely. Package-less → this
// file joins the plugin's concatenated schema and resolves via kindDefPaths.

// #KindCluster — the envelope the generated kind Cluster config must satisfy.
// `[<Node>, ...<Node>]` requires at least one node, EVERY node with a valid role.
#KindCluster: {
	kind:       "Cluster"
	apiVersion: =~"^kind\\.x-k8s\\.io/"
	nodes: [#KindClusterNode, ...#KindClusterNode]
	...
}

#KindClusterNode: {
	role: "control-plane" | "worker"
	...
}
