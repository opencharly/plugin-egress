// Egress schema for the netfilter ruleset charly installs on a Firecracker host — the FORWARD/NAT rules a
// pool needs so guest traffic reaches the network. Modelled as the structured PRE-IMAGE of the ruleset, the
// same two-layer approach the libvirt-XML and service-unit artifacts use, so a ruleset is validated BEFORE
// it reaches iptables rather than after.
//
// Hand-authored, so it stays close({...}): a typo in a chain name or a target is exactly what this gate is
// for, and an open schema could not catch one.
#NetfilterRules: close({
	// forward — the FORWARD table: the rules that let pool guests reach out and back.
	forward?: [...#NetfilterRule]
	// nat — the NAT table: masquerade for egress, DNAT for published ports.
	nat?: [...#NetfilterRule]
})

#NetfilterRule: close({
	chain:  string & !=""
	target: "ACCEPT" | "DROP" | "RETURN" | "MASQUERADE" | "DNAT" | "SNAT"
	proto?: "tcp" | "udp" | "icmp" | "all"
	source?:        string & !=""
	destination?:   string & !=""
	dport?:         int & >0 & <65536
	to_destination?: string & !=""
	comment?:       string
})
