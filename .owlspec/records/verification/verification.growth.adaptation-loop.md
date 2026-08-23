+++
version = 2
id = "verification.growth.adaptation-loop"
kind = "verification"
method = "automatic"
target = "test/run.sh"
+++

# Verify the OwlGrowth adaptation loop

Run `./test/run.sh`. The scenario records observed experiences, creates scoped guidance, observes external success, and checks that review recommends strengthening evidence-backed guidance with bounded recent-observation and field projections. It rejects malformed JSON-RPC lines, wrong protocol versions, non-scalar request ids, empty or malformed JSON evidence, invalid known scope field types, adaptations without a supporting experience, unknown experience references, self-seeded adaptation evidence, and new observations for retired adaptations so only valid observed outcomes change the counts.
