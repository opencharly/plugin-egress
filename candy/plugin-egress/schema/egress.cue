// plugin-egress's OWN self-contained CUE schema — the plugin's declaration
// surface, served over Describe exactly like every other
// plugin's schema (there is no schema-less plugin):
//
//  1. SERVE over Describe — the host splices `base ++ plugin` at the load gate
//     (registerPluginUnitSchema), so the plugin's declarations travel WITH it and
//     a self-contained schema that will not splice is a LOUD load failure.
//  2. DOCUMENT — `charly docs generate` renders this plugin's page from its
//     providers + this schema + the candy `description:`.
//
// verb:egress's authored input is NOT a plugin_input: callers resolve the word and
// Invoke OpValidate with a `{kind, data}` envelope (the rendered artifact + the
// egress kind it must validate against), so this schema DOCUMENTS the verb contract.
// The egress VALIDATION schemas (#RenderedText, #K8sObject, ...) stay INTERNAL to the
// plugin (egress-schemas/) and are never part of the served blob. SELF-CONTAINED: it
// references no base def, so it compiles STANDALONE (the property that lets the SDK
// compile it serve-side).
#EgressPlugin: {
	// The capability word the plugin serves.
	verb: "egress"

	// What the verb does, in one line (the public-docs surface): validate an egress
	// artifact against its kind's CUE schema BEFORE the bytes hit disk.
	contract: string & !=""
}
