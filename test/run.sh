#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

call() {
    printf '%s\n' "$1" | OWL_GROWTH_DATA_DIR="$tmp/data" "$root/bin/owlgrowth-mcp"
}

out=$(call '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
printf '%s\n' "$out" | grep '"protocolVersion":"2024-11-05"' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"discover","arguments":{}}}')
printf '%s\n' "$out" | grep 'record_experience' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"exp-a","project":"project-a","task":"dependency debugging","action":"changed package.json without checking lockfile","outcome":{"result":"failure"},"evidence":"test exit code 1"}}}')
printf '%s\n' "$out" | grep 'exp-a' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-lockfile","guidance":"check the lockfile before changing dependencies","scope":{"ecosystem":"node","task":"dependency debugging"},"source_experience_ids":["exp-a"]}}}')
printf '%s\n' "$out" | grep 'adapt-lockfile' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-lockfile","project":"project-a","result":"success","evidence":"test exit code 0"}}}')
printf '%s\n' "$out" | grep 'success.*1' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"exp-b","project":"project-b","task":"dependency debugging","action":"checked lockfile before changing dependencies","outcome":{"result":"success"},"evidence":"build exit code 0"}}}')
printf '%s\n' "$out" | grep 'project-b' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-lockfile","project":"project-b","result":"success","evidence":"build exit code 0"}}}')
printf '%s\n' "$out" | grep 'success.*2' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"revise_adaptation","arguments":{"adaptation_id":"adapt-lockfile","guidance":"check the lockfile and compare the dependency diff first","scope":{"ecosystem":"node","task":"dependency debugging"},"source_experience_ids":["exp-a","exp-b"],"reason":"confirmed by two project outcomes"}}}')
printf '%s\n' "$out" | grep 'exp-b' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"dependency debugging","project":"project-b"}}}')
printf '%s\n' "$out" | grep 'adapt-lockfile' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"review_adaptation","arguments":{"adaptation_id":"adapt-lockfile"}}}')
printf '%s\n' "$out" | grep 'strengthen' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-bad","guidance":"skip validation","scope":{"task":"dependency debugging"},"source_experience_ids":["exp-a"]}}}')
printf '%s\n' "$out" | grep 'adapt-bad' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-bad","result":"failure","evidence":"test exit code 1"}}}')
printf '%s\n' "$out" | grep 'failure.*1' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"review_adaptation","arguments":{"adaptation_id":"adapt-bad"}}}')
printf '%s\n' "$out" | grep 'refine-or-narrow' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"retire_adaptation","arguments":{"adaptation_id":"adapt-bad"}}}')
printf '%s\n' "$out" | grep 'retired' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":15,"method":"resources/read","params":{"uri":"owlgrowth://guidance"}}')
printf '%s\n' "$out" | grep 'check the lockfile' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-alpha-only","guidance":"use the alpha-only migration script","scope":{"project":"project-a","task":"private migration"}}}}')
printf '%s\n' "$out" | grep 'adapt-alpha-only' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"private migration","project":"project-b"}}}')
printf '%s\n' "$out" | grep 'count.*0' >/dev/null

n=1
while [ "$n" -le 21 ]; do
    call "{\"jsonrpc\":\"2.0\",\"id\":$((n + 18)),\"method\":\"tools/call\",\"params\":{\"name\":\"record_adaptation\",\"arguments\":{\"adaptation_id\":\"bounded-$n\",\"guidance\":\"bounded guidance $n\",\"scope\":{\"task\":\"bounded\"}}}}" >/dev/null
    n=$((n + 1))
done

out=$(call '{"jsonrpc":"2.0","id":40,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"bounded","limit":1}}}')
printf '%s\n' "$out" | grep 'truncated.*true' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":41,"method":"resources/read","params":{"uri":"owlgrowth://guidance"}}')
printf '%s\n' "$out" | grep 'more adaptation' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":42,"method":"tools/call","params":{"name":"record_experience","arguments":{"task":"missing evidence","action":"did something","outcome":"unknown"}}}')
printf '%s\n' "$out" | grep 'requires argument' >/dev/null

printf '%s\n' 'OwlGrowth tests passed.'
