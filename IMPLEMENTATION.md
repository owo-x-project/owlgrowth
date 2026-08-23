# OwlGrowth implementation

OwlGrowth is a small MCP server for turning observed work outcomes into scoped, revisable action guidance. It does not manage project knowledge, specifications, or decisions.

## Run

```sh
OWL_GROWTH_DATA_DIR=.owlgrowth ./bin/owlgrowth-mcp
```

The process speaks newline-delimited JSON-RPC over stdin/stdout. Notifications without an id are executed without emitting a response. Its only product interface is MCP. The launcher is POSIX `sh`; the server is POSIX `awk` and has no Python, jq, SQLite, HTTP server, or MCP SDK dependency.

The default data directory is `.owlgrowth` below the caller's working directory. Set `OWL_GROWTH_DATA_DIR` when several projects intentionally share the same adaptation store. Experiences retain their `project` field; adaptations retain an explicit `scope` and therefore are not silently generalized.

## Data model

The server appends JSON Lines records to:

- `experiences.jsonl`: immutable observed `Task`, `Action`, `Outcome`, and required external `Evidence`, scoped to a project.
- `adaptations.jsonl`: the latest state of scoped `guidance`, its source experience ids, external evidence counts/observations, and active/retired status. Updates append a new version; old lines remain audit history.

An adaptation is not an experience. `observe_adaptation` only counts a result when an evidence value is supplied, and `review_adaptation` recommends `strengthen`, `refine-or-narrow`, or `gather-more` from observed counts. `revise_adaptation` changes guidance/scope without losing evidence, while `retire_adaptation` preserves history while removing guidance from recommendations.

The server rejects malformed JSON-RPC request lines, empty task/action/guidance/evidence values, malformed JSON Outcome/Evidence values, invalid known scope field types/values, and identifiers longer than 256 characters. Each Adaptation must cite at least one existing Experience. New Adaptations always start with zero external evidence; only `observe_adaptation` can add an observed result, and retired Adaptations cannot receive new observations. Observations must identify a project and task when the adaptation scope requires them; out-of-scope observations are not counted. Every list tool has a hard maximum of 20 items, even when a larger limit is requested. Public responses project text and raw values to at most 512 characters/bytes with truncation metadata, expose evidence counts and source ids rather than full history, and show only five bounded recent observations; the append-only JSONL history retains the complete observed values.

## MCP surface

Use `discover` first when routing is unclear. The tools are deliberately narrow: find/record experiences, record/observe/review/revise/retire adaptations, and recommend the next action. The `owlgrowth://guidance` resource is bounded to avoid context growth; use `recommend_action` with task/project/scope for targeted guidance. There is no product CLI or OwlKnowledge/Owlspec integration.

## Verification

```sh
./test/run.sh
```
