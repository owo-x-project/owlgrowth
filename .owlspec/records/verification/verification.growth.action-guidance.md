+++
version = 2
id = "verification.growth.action-guidance"
kind = "verification"
method = "automatic"
target = "test/run.sh"
+++

# Verify next-action guidance

Run `./test/run.sh`. The scenario requests `recommend_action` for the next dependency task and checks that active scoped guidance is returned while an explicit project mismatch is excluded.
