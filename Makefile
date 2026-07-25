# Convenience targets. See README.md for the full walkthrough.
.PHONY: setup verify demo1 demo2-setup demo2-attack demo2-defend clean

setup:            ## create kind cluster + Calico
	cd cluster && ./setup-kind.sh

verify:           ## prove NetworkPolicy is enforced (do this before the talk)
	cd cluster && ./verify-netpol.sh

demo1:            ## run supply-chain + hardening demo
	cd demo1-supply-chain-hardening && ./run-demo1.sh

demo2-setup:      ## deploy ollama + agent + attacker, pull model
	cd demo2-prompt-injection-exfil && ./setup-demo2.sh

demo2-attack:     ## PHASE A — vulnerable: exfil succeeds
	cd demo2-prompt-injection-exfil && ./run-demo2-vulnerable.sh

demo2-defend:     ## PHASE B — defended: NetworkPolicy blocks exfil
	cd demo2-prompt-injection-exfil && ./run-demo2-defended.sh

clean:            ## delete the kind cluster
	cd cluster && ./teardown.sh
