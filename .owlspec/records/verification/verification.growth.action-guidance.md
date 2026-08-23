+++
version = 2
id = "verification.growth.action-guidance"
kind = "verification"
method = "automatic"
target = "test/run.sh"
+++

# Verify next-action guidance

Run `./test/run.sh`. The scenario requests `recommend_action` for the next dependency task and checks that active scoped guidance is returned while explicit project mismatches and unqualified project-scoped guidance are excluded. It also verifies stable ordering, a hard maximum of 20 results even for an oversized limit, and aggregate evidence output without full observation history.
