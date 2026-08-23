+++
version = 2
id = "verification.growth.adaptation-loop"
kind = "verification"
method = "automatic"
target = "test/run.sh"
+++

# Verify the OwlGrowth adaptation loop

Run `./test/run.sh`. The scenario records observed experiences, creates scoped guidance, observes external success, and checks that review recommends strengthening evidence-backed guidance with bounded recent-observation and field projections. It verifies that id-less JSON-RPC notifications emit no response and rejects malformed JSON-RPC lines, wrong protocol versions, non-scalar request ids, duplicate object keys, invalid `params` shapes, oversized requests, invalid positive-integer limits, unknown scope fields, empty or malformed JSON evidence, invalid known scope field types, adaptations without a supporting experience, unknown experience references, self-seeded adaptation evidence, and new observations for retired adaptations so only valid observed outcomes change the counts.

The regression cases also cover wrong optional JSON types, whitespace-only values, duplicate experience citations, escaped/raw Unicode identifier equivalence including surrogate pairs, missing ecosystem scope, bounded observation results, duplicate truncation metadata, partial and semantically invalid persisted lines on restart, malformed lock-owner recovery, signal-safe owner-only lock cleanup, generated-id writes from concurrent processes, and concurrent observation updates preserving every external result.
