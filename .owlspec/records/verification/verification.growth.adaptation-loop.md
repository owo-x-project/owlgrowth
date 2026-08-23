+++
version = 2
id = "verification.growth.adaptation-loop"
kind = "verification"
method = "automatic"
target = "test/run.sh"
+++

# Verify the OwlGrowth adaptation loop

Run `./test/run.sh`. The scenario records observed experiences, creates scoped guidance, observes external success, and checks that review recommends strengthening evidence-backed guidance. It also rejects empty evidence, unknown experience references, and self-seeded adaptation evidence so only observed outcomes change the counts.
