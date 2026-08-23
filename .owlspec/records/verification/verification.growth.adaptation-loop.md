+++
version = 2
id = "verification.growth.adaptation-loop"
kind = "verification"
method = "automatic"
target = "test/run.sh"
+++

# Verify the OwlGrowth adaptation loop

Run `./test/run.sh`. The scenario records observed experiences, creates scoped guidance, observes external success, and checks that review recommends strengthening evidence-backed guidance with bounded recent-observation and field projections. It verifies that id-less JSON-RPC notifications emit no response and rejects malformed JSON-RPC lines, wrong protocol versions, non-scalar request ids, duplicate object keys, invalid `params` shapes, oversized requests, invalid positive-integer limits, unknown scope fields, empty durable project values, empty or malformed JSON evidence, invalid known scope field types, adaptations without a supporting experience, unknown experience references, self-seeded adaptation evidence, and new observations for retired adaptations so only valid observed outcomes change the counts.

The regression cases also cover wrong optional JSON types, whitespace-only values and identifiers, duplicate experience citations, exact evidence-counter/observation agreement, duplicate immutable experience lines and stale active lines after retirement, escaped/raw Unicode identifier equivalence including surrogate pairs, missing ecosystem scope, bounded observation results, aggregate 32 KiB tool-text projections, duplicate truncation metadata, UTF-8-boundary-safe 512-byte projections verified with `iconv`, invalid UTF-8 normalization in responses and persisted JSONL, malformed id-less request silence, partial and semantically invalid persisted lines on restart, malformed/dead/zero-PID lock recovery, signal-safe owner-only lock cleanup, shutdown/exit lifecycle, generated-id collision retry, and concurrent observation updates preserving every external result.
