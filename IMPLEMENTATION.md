# OwlGrowth implementation

OwlGrowth is a small MCP server for turning observed work outcomes into scoped, revisable action guidance. It does not manage project knowledge, specifications, or decisions.

## Run

```sh
OWL_GROWTH_DATA_DIR=.owlgrowth ./bin/owlgrowth-mcp
```

The process speaks newline-delimited JSON-RPC over stdin/stdout. Its only product interface is MCP. The launcher is POSIX `sh`; the server is POSIX `awk` and has no Python, jq, SQLite, HTTP server, or MCP SDK dependency.

The default data directory is `.owlgrowth` below the caller's working directory. Set `OWL_GROWTH_DATA_DIR` when several projects intentionally share the same adaptation store. Experiences retain their `project` field; adaptations retain an explicit `scope` and therefore are not silently generalized.

## Data model

The server appends JSON Lines records to:

- `experiences.jsonl`: immutable observed `Task`, `Action`, `Outcome`, and required external `Evidence`, scoped to a project.
- `adaptations.jsonl`: the latest state of scoped `guidance`, its source experience ids, external evidence counts/observations, and active/retired status. Updates append a new version; old lines remain audit history.

An adaptation is not an experience. `observe_adaptation` only counts a result when an evidence value is supplied, and `review_adaptation` recommends `strengthen`, `refine-or-narrow`, or `gather-more` from observed counts. `revise_adaptation` changes guidance/scope without losing evidence, while `retire_adaptation` preserves history while removing guidance from recommendations.

The server rejects empty task/action/guidance/evidence values and rejects adaptation references to unknown experiences. New Adaptations always start with zero external evidence; only `observe_adaptation` can add an observed result. Observations must identify a project and task when the adaptation scope requires them; out-of-scope observations are not counted. Bounded lists are returned in stable adaptation/experience-id order so repeated context reads do not reshuffle the agent's input.

## MCP surface

Use `discover` first when routing is unclear. The tools are deliberately narrow: find/record experiences, record/observe/review/revise/retire adaptations, and recommend the next action. The `owlgrowth://guidance` resource is bounded to avoid context growth; use `recommend_action` with task/project/scope for targeted guidance. There is no product CLI or OwlKnowledge/Owlspec integration.

## Verification

```sh
./test/run.sh
```
