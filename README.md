# OwlGrowth

## Project overview

OwlGrowth is a small, standalone MCP server that turns observed work outcomes into better future actions. It stores project-scoped experiences and reusable action guidance through a stdio MCP interface.

## Concept

OwlGrowth records Task, Action, Outcome, and Evidence as an Experience. Multiple Experiences can produce an Adaptation: scoped guidance that is revised by externally observable results instead of treated as permanent knowledge.

## Scenarios it solves

- Avoid repeating the same failure by using evidence from earlier work.
- Reuse successful procedures while keeping their project and scope boundaries.
- Review action guidance using tests, exit codes, builds, approvals, or task completion results.

## Installation

Install with APM:

```sh
apm install owo-x-project/owlgrowth --target codex,claude
```

Run from source:

```sh
git clone https://github.com/owo-x-project/owlgrowth.git
cd owlgrowth
./bin/owlgrowth-mcp
```

## License

MIT License. See [LICENSE](LICENSE).
