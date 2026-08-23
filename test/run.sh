#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

call() {
    printf '%s\n' "$1" | OWL_GROWTH_DATA_DIR="$tmp/data" "$root/bin/owlgrowth-mcp"
}

call_data() {
    printf '%s\n' "$2" | OWL_GROWTH_DATA_DIR="$1" "$root/bin/owlgrowth-mcp"
}

out=$(call '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
printf '%s\n' "$out" | grep '"protocolVersion":"2024-11-05"' >/dev/null

out=$(call '{"jsonrpc":"2.0","method":"ping"}')
[ -z "$out" ]

out=$(printf '%s\n' '{"jsonrpc":"2.0","method":' | OWL_GROWTH_DATA_DIR="$tmp/malformed-notification-data" "$root/bin/owlgrowth-mcp")
[ -z "$out" ]

out=$(printf '%s\n' '{"jsonrpc":"1.0","method":"ping"}' '{"jsonrpc":"2.0","method":"ping"}' | OWL_GROWTH_DATA_DIR="$tmp/notification-data" "$root/bin/owlgrowth-mcp")
[ -z "$out" ]

zero_lock_data="$tmp/zero-lock-data"
mkdir -p "$zero_lock_data"
printf '%s\n' '0' > "$zero_lock_data/.owlgrowth.lock"
out=$(call_data "$zero_lock_data" '{"jsonrpc":"2.0","id":102,"method":"ping"}')
printf '%s\n' "$out" | grep '"result":{}' >/dev/null
[ ! -e "$zero_lock_data/.owlgrowth.lock" ]

out=$(printf '%s\n' '{"jsonrpc":"2.0","id":101,"method":"shutdown"}' '{"jsonrpc":"2.0","method":"exit"}' '{"jsonrpc":"2.0","id":102,"method":"ping"}' | OWL_GROWTH_DATA_DIR="$tmp/lifecycle-data" "$root/bin/owlgrowth-mcp")
[ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ]
printf '%s\n' "$out" | grep '"result":null' >/dev/null

out=$(call '{"jsonrpc":"1.0","id":1,"method":"ping"}')
printf '%s\n' "$out" | grep 'requires jsonrpc 2.0' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":{"bad":1},"method":"ping"}')
printf '%s\n' "$out" | grep 'request id must be a string' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":1,"method":"ping","method":"not-found"}')
printf '%s\n' "$out" | grep 'parse error' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":1,"method":"initialize","params":false}')
printf '%s\n' "$out" | grep 'params must be an object or array' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"discover","arguments":{}}}')
printf '%s\n' "$out" | grep 'record_experience' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"exp-a","project":"project-a","task":"dependency debugging","action":"changed package.json without checking lockfile","outcome":{"result":"failure"},"evidence":"test exit code 1"}}}')
printf '%s\n' "$out" | grep 'exp-a' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":31,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"emoji-\ud83d\ude00","task":"unicode","action":"record","outcome":"success","evidence":"unicode round trip"}}}')
printf '%s\n' "$out" | grep 'emoji-' >/dev/null
out=$(call '{"jsonrpc":"2.0","id":32,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"emoji-😀","task":"unicode duplicate","action":"record","outcome":"success","evidence":"duplicate"}}}')
printf '%s\n' "$out" | grep 'experience already exists' >/dev/null
printf '%s\n' "$out" | jq -e . >/dev/null

out=$(call '{"jsonrpc":"2.0","id":33,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"whitespace-id","project":" ","task":"whitespace id","action":"reject","outcome":"success","evidence":"must reject"}}}')
printf '%s\n' "$out" | grep 'requires a non-empty string argument' >/dev/null
if grep 'whitespace-id' "$tmp/data/experiences.jsonl" >/dev/null; then exit 1; fi

out=$(call '{"jsonrpc":"2.0","id":34,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":" ","task":"whitespace identifier","action":"reject","outcome":"success","evidence":"must reject"}}}')
printf '%s\n' "$out" | grep 'requires a non-empty identifier' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-lockfile","guidance":"check the lockfile before changing dependencies","scope":{"ecosystem":"node","task":"dependency debugging"},"source_experience_ids":["exp-a"]}}}')
printf '%s\n' "$out" | grep 'adapt-lockfile' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-lockfile","project":"project-a","task":"dependency debugging","ecosystem":"node","result":"success","evidence":"test exit code 0"}}}')
printf '%s\n' "$out" | grep 'success.*1' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"exp-b","project":"project-b","task":"dependency debugging","action":"checked lockfile before changing dependencies","outcome":{"result":"success"},"evidence":"build exit code 0"}}}')
printf '%s\n' "$out" | grep 'project-b' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-lockfile","project":"project-b","task":"dependency debugging","ecosystem":"node","result":"success","evidence":"build exit code 0"}}}')
printf '%s\n' "$out" | grep 'success.*2' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"revise_adaptation","arguments":{"adaptation_id":"adapt-lockfile","guidance":"check the lockfile and compare the dependency diff first","scope":{"ecosystem":"node","task":"dependency debugging"},"source_experience_ids":["exp-a","exp-b"],"reason":"confirmed by two project outcomes"}}}')
printf '%s\n' "$out" | grep 'exp-b' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"dependency debugging","project":"project-b"}}}')
printf '%s\n' "$out" | grep 'adapt-lockfile' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"review_adaptation","arguments":{"adaptation_id":"adapt-lockfile"}}}')
printf '%s\n' "$out" | grep 'strengthen' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-bad","guidance":"skip validation","scope":{"task":"dependency debugging"},"source_experience_ids":["exp-a"]}}}')
printf '%s\n' "$out" | grep 'adapt-bad' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-bad","project":"project-a","task":"dependency debugging","result":"failure","evidence":"test exit code 1"}}}')
printf '%s\n' "$out" | grep 'failure.*1' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"review_adaptation","arguments":{"adaptation_id":"adapt-bad"}}}')
printf '%s\n' "$out" | grep 'refine-or-narrow' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"retire_adaptation","arguments":{"adaptation_id":"adapt-bad"}}}')
printf '%s\n' "$out" | grep 'retired' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":141,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-bad","project":"project-a","task":"dependency debugging","result":"success","evidence":"must not observe retired"}}}')
printf '%s\n' "$out" | grep 'cannot observe retired' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":15,"method":"resources/read","params":{"uri":"owlgrowth://guidance"}}')
printf '%s\n' "$out" | grep 'check the lockfile' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-alpha-only","guidance":"use the alpha-only migration script","scope":{"project":"project-a","task":"private migration"},"source_experience_ids":["exp-a"]}}}')
printf '%s\n' "$out" | grep 'adapt-alpha-only' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"private migration","project":"project-b"}}}')
printf '%s\n' "$out" | grep 'count.*0' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"private migration"}}}')
printf '%s\n' "$out" | grep 'count.*0' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-alpha-only","project":"project-b","task":"private migration","result":"success","evidence":"wrong project"}}}')
printf '%s\n' "$out" | grep 'outside adaptation scope' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-orphan","guidance":"orphan guidance","scope":{"task":"dependency debugging"},"source_experience_ids":["missing-experience"]}}}')
printf '%s\n' "$out" | grep 'unknown experience' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-self-rated","guidance":"self-rated guidance","scope":{"task":"dependency debugging"},"source_experience_ids":["exp-a"],"evidence":{"success":99}}}}')
printf '%s\n' "$out" | grep 'does not accept evidence' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":22,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-unproven","guidance":"unproven guidance","scope":{"task":"dependency debugging"}}}}')
printf '%s\n' "$out" | grep 'at least one experience id' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":23,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-bad-scope","guidance":"bad scope must not be stored","scope":{"project":123},"source_experience_ids":["exp-a"]}}}')
printf '%s\n' "$out" | grep "scope field 'project' must be a non-empty string" >/dev/null
if grep 'adapt-bad-scope' "$tmp/data/adaptations.jsonl" >/dev/null; then exit 1; fi

out=$(call '{"jsonrpc":"2.0","id":24,"method":"tools/call","params":{"name":"recommend_action","arguments":{"scope":[]}}}')
printf '%s\n' "$out" | grep 'requires a valid object argument' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":25,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"bad-optional-type","project":123,"task":"t","action":"a","outcome":"o","evidence":"e"}}}')
printf '%s\n' "$out" | grep 'requires .*string argument' >/dev/null
if grep 'bad-optional-type' "$tmp/data/experiences.jsonl" >/dev/null; then exit 1; fi

out=$(call '{"jsonrpc":"2.0","id":251,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"empty-project","project":"","task":"t","action":"a","outcome":"o","evidence":"e"}}}')
printf '%s\n' "$out" | grep 'non-empty string argument' >/dev/null
if grep 'empty-project' "$tmp/data/experiences.jsonl" >/dev/null; then exit 1; fi

out=$(call '{"jsonrpc":"2.0","id":26,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"bad-whitespace","task":"t","action":"a","outcome":" ","evidence":"  "}}}')
printf '%s\n' "$out" | grep 'non-empty argument' >/dev/null
if grep 'bad-whitespace' "$tmp/data/experiences.jsonl" >/dev/null; then exit 1; fi

out=$(call '{"jsonrpc":"2.0","id":27,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"duplicate-source-ids","guidance":"duplicate ids must be rejected","scope":{"task":"dependency debugging"},"source_experience_ids":["exp-a","exp-a"]}}}')
printf '%s\n' "$out" | grep 'duplicate experience id' >/dev/null
if grep 'duplicate-source-ids' "$tmp/data/adaptations.jsonl" >/dev/null; then exit 1; fi

out=$(call '{"jsonrpc":"2.0","id":28,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-lockfile","project":"project-a","task":"dependency debugging","result":"success","evidence":"missing ecosystem"}}}')
printf '%s\n' "$out" | grep 'requires ecosystem' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":281,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"adapt-lockfile","project":"","task":"dependency debugging","ecosystem":"node","result":"success","evidence":"empty project must not be persisted"}}}')
printf '%s\n' "$out" | grep 'non-empty string argument' >/dev/null

call '{"jsonrpc":"2.0","id":80,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"adapt-detail","guidance":"detail guidance","scope":{"task":"detail"},"source_experience_ids":["exp-a"]}}}' >/dev/null
n=1
while [ "$n" -le 6 ]; do
    call "{\"jsonrpc\":\"2.0\",\"id\":$((n + 80)),\"method\":\"tools/call\",\"params\":{\"name\":\"observe_adaptation\",\"arguments\":{\"adaptation_id\":\"adapt-detail\",\"project\":\"project-a\",\"task\":\"detail\",\"result\":\"success\",\"evidence\":\"detail $n\"}}}" >/dev/null
    n=$((n + 1))
done
out=$(call '{"jsonrpc":"2.0","id":90,"method":"tools/call","params":{"name":"review_adaptation","arguments":{"adaptation_id":"adapt-detail"}}}')
printf '%s\n' "$out" | grep 'recent_observations' >/dev/null
printf '%s\n' "$out" | grep 'truncated.*true' >/dev/null

n=1
while [ "$n" -le 21 ]; do
    call "{\"jsonrpc\":\"2.0\",\"id\":$((n + 22)),\"method\":\"tools/call\",\"params\":{\"name\":\"record_adaptation\",\"arguments\":{\"adaptation_id\":\"bounded-$n\",\"guidance\":\"bounded guidance $n\",\"scope\":{\"task\":\"bounded\"},\"source_experience_ids\":[\"exp-a\"]}}}" >/dev/null
    n=$((n + 1))
done

out=$(call '{"jsonrpc":"2.0","id":44,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"bounded","limit":1}}}')
printf '%s\n' "$out" | grep 'truncated.*true' >/dev/null
printf '%s\n' "$out" | grep 'bounded-1' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":48,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"bounded","limit":999999}}}')
printf '%s\n' "$out" | grep 'count.*20' >/dev/null
printf '%s\n' "$out" | grep 'truncated.*true' >/dev/null
if printf '%s\n' "$out" | grep 'observations' >/dev/null; then exit 1; fi

out=$(call '{"jsonrpc":"2.0","id":481,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"bounded","limit":"1"}}}')
printf '%s\n' "$out" | grep 'positive integer argument' >/dev/null
out=$(call '{"jsonrpc":"2.0","id":482,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"bounded","limit":0}}}')
printf '%s\n' "$out" | grep 'positive integer argument' >/dev/null
out=$(call '{"jsonrpc":"2.0","id":483,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"bounded","scope":{"unknown":"field"}}}}')
printf '%s\n' "$out" | grep 'scope contains unknown field' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":45,"method":"resources/read","params":{"uri":"owlgrowth://guidance"}}')
printf '%s\n' "$out" | grep 'more adaptation' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":46,"method":"tools/call","params":{"name":"record_experience","arguments":{"task":"missing evidence","action":"did something","outcome":"unknown"}}}')
printf '%s\n' "$out" | grep 'requires .*evidence' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":47,"method":"tools/call","params":{"name":"record_experience","arguments":{"task":"empty evidence","action":"did something","outcome":"unknown","evidence":""}}}')
printf '%s\n' "$out" | grep 'non-empty argument' >/dev/null

out=$(call '{"jsonrpc":"2.0","id":471,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"bad-json","task":"bad json","action":"bad json","outcome":{"broken":},"evidence":"observed"}}}')
printf '%s\n' "$out" | grep 'parse error' >/dev/null

long_text=$(awk 'BEGIN { for (i = 1; i <= 6000; i++) printf "x" }')
out=$(call "{\"jsonrpc\":\"2.0\",\"id\":472,\"method\":\"tools/call\",\"params\":{\"name\":\"record_experience\",\"arguments\":{\"experience_id\":\"bounded-text\",\"task\":\"bounded text\",\"action\":\"$long_text\",\"outcome\":{\"result\":\"$long_text\"},\"evidence\":\"$long_text\"}}}")
printf '%s\n' "$out" | grep 'outcome_truncated.*true' >/dev/null
printf '%s\n' "$out" | grep 'evidence_truncated.*true' >/dev/null
if [ "$(printf '%s\n' "$out" | grep -o 'outcome_truncated' | wc -l)" -ne 1 ]; then exit 1; fi
if [ "$(printf '%s\n' "$out" | grep -o 'evidence_truncated' | wc -l)" -ne 1 ]; then exit 1; fi
if [ "$(printf '%s\n' "$out" | wc -c)" -gt 3000 ]; then exit 1; fi
grep 'bounded-text' "$tmp/data/experiences.jsonl" >/dev/null

utf8_text=$(awk 'BEGIN { for (i = 1; i <= 171; i++) printf "\342\202\254" }')
out=$(call "{\"jsonrpc\":\"2.0\",\"id\":4721,\"method\":\"tools/call\",\"params\":{\"name\":\"record_experience\",\"arguments\":{\"experience_id\":\"utf8-boundary\",\"task\":\"utf8 boundary\",\"action\":\"$utf8_text\",\"outcome\":\"success\",\"evidence\":\"boundary regression\"}}}")
printf '%s\n' "$out" | grep 'action_truncated.*true' >/dev/null
printf '%s\n' "$out" | iconv -f UTF-8 -t UTF-8 >/dev/null

out=$(printf '%b\n' '{"jsonrpc":"2.0","id":4722,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"bad-\377","task":"invalid utf8","action":"record","outcome":"success","evidence":"sanitized"}}}' | OWL_GROWTH_DATA_DIR="$tmp/invalid-utf8-data" "$root/bin/owlgrowth-mcp")
printf '%s\n' "$out" | iconv -f UTF-8 -t UTF-8 >/dev/null
iconv -f UTF-8 -t UTF-8 "$tmp/invalid-utf8-data/experiences.jsonl" >/dev/null

long_result=$(awk 'BEGIN { for (i = 1; i <= 10000; i++) printf "x" }')
out=$(call "{\"jsonrpc\":\"2.0\",\"id\":473,\"method\":\"tools/call\",\"params\":{\"name\":\"observe_adaptation\",\"arguments\":{\"adaptation_id\":\"adapt-lockfile\",\"project\":\"project-a\",\"task\":\"dependency debugging\",\"ecosystem\":\"node\",\"result\":\"$long_result\",\"evidence\":\"bounded result\"}}}")
if [ "$(printf '%s\n' "$out" | wc -c)" -gt 3000 ]; then exit 1; fi

oversized_request=$(awk 'BEGIN { for (i = 1; i <= 66000; i++) printf "x" }')
out=$(call "{\"jsonrpc\":\"2.0\",\"id\":474,\"method\":\"ping\",\"params\":{\"padding\":\"$oversized_request\"}}")
printf '%s\n' "$out" | grep 'request exceeds 65536 characters' >/dev/null

n=1
while [ "$n" -le 21 ]; do
    call "{\"jsonrpc\":\"2.0\",\"id\":$((n + 48)),\"method\":\"tools/call\",\"params\":{\"name\":\"record_experience\",\"arguments\":{\"experience_id\":\"bounded-exp-$n\",\"project\":\"project-a\",\"task\":\"bounded experience\",\"action\":\"run $n\",\"outcome\":{\"result\":\"success\"},\"evidence\":\"exit $n\"}}}" >/dev/null
    n=$((n + 1))
done
out=$(call '{"jsonrpc":"2.0","id":70,"method":"tools/call","params":{"name":"find_experiences","arguments":{"query":"bounded experience","limit":999999}}}')
printf '%s\n' "$out" | grep 'count.*20' >/dev/null
printf '%s\n' "$out" | grep 'truncated.*true' >/dev/null

if grep 'adapt-orphan' "$tmp/data/adaptations.jsonl" >/dev/null; then exit 1; fi
if grep 'adapt-self-rated' "$tmp/data/adaptations.jsonl" >/dev/null; then exit 1; fi
if grep 'adapt-unproven' "$tmp/data/adaptations.jsonl" >/dev/null; then exit 1; fi
if grep 'empty evidence' "$tmp/data/experiences.jsonl" >/dev/null; then exit 1; fi

partial_data="$tmp/partial-data"
mkdir -p "$partial_data"
printf '%s' '{"id":"partial-experience"' > "$partial_data/experiences.jsonl"
out=$(call_data "$partial_data" '{"jsonrpc":"2.0","id":474,"method":"tools/call","params":{"name":"find_experiences","arguments":{}}}')
printf '%s\n' "$out" | grep 'count.*0' >/dev/null

reload_data="$tmp/reload-data"
mkdir -p "$reload_data"
printf '%s\n' '{"id":"reload-exp","kind":"experience","project":"reload-project","task":"reload","action":"validated action","outcome":"success","evidence":"observed"}' > "$reload_data/experiences.jsonl"
printf '%s\n' '{"id":"reload-good","kind":"adaptation","guidance":"reload guidance","scope":{"task":"reload"},"source_experience_ids":["reload-exp"],"evidence":{"success":0,"failure":0,"other":0,"observations":[]},"status":"active"}' > "$reload_data/adaptations.jsonl"
printf '%s\n' '{"id":"reload-counter","kind":"adaptation","guidance":"must be ignored","scope":{"task":"reload"},"source_experience_ids":["reload-exp"],"evidence":{"success":99,"failure":0,"other":0,"observations":[]},"status":"active"}' >> "$reload_data/adaptations.jsonl"
printf '%s\n' '{"id":"reload-retired","kind":"adaptation","guidance":"retired guidance","scope":{"task":"reload"},"source_experience_ids":["reload-exp"],"evidence":{"success":0,"failure":0,"other":0,"observations":[]},"status":"active"}' >> "$reload_data/adaptations.jsonl"
printf '%s\n' '{"id":"reload-retired","kind":"adaptation","guidance":"retired guidance","scope":{"task":"reload"},"source_experience_ids":["reload-exp"],"evidence":{"success":0,"failure":0,"other":0,"observations":[]},"status":"retired"}' >> "$reload_data/adaptations.jsonl"
printf '%s\n' '{"id":"reload-retired","kind":"adaptation","guidance":"stale active guidance","scope":{"task":"reload"},"source_experience_ids":["reload-exp"],"evidence":{"success":0,"failure":0,"other":0,"observations":[]},"status":"active"}' >> "$reload_data/adaptations.jsonl"
printf '%s\n' '{"id":"reload-unknown","kind":"adaptation","guidance":"must be ignored","scope":{"task":"reload"},"source_experience_ids":["missing"],"evidence":{"success":0,"failure":0,"other":0,"observations":[]},"status":"active"}' >> "$reload_data/adaptations.jsonl"
printf '%s\n' '{"id":"reload-duplicate","kind":"adaptation","guidance":"must be ignored","scope":{"task":"reload"},"source_experience_ids":["reload-exp","reload-exp"],"evidence":{"success":0,"failure":0,"other":0,"observations":[]},"status":"active"}' >> "$reload_data/adaptations.jsonl"
printf '%s\n' '{"id":"reload-unknown-scope","kind":"adaptation","guidance":"must be ignored","scope":{"task":"reload","unknown":"field"},"source_experience_ids":["reload-exp"],"evidence":{"success":0,"failure":0,"other":0,"observations":[]},"status":"active"}' >> "$reload_data/adaptations.jsonl"
printf '%s\n' '{"id":"reload-duplicate-key","id":"reload-duplicate-key","kind":"adaptation","guidance":"must be ignored","scope":{"task":"reload"},"source_experience_ids":["reload-exp"],"evidence":{"success":0,"failure":0,"other":0,"observations":[]},"status":"active"}' >> "$reload_data/adaptations.jsonl"
out=$(call_data "$reload_data" '{"jsonrpc":"2.0","id":475,"method":"tools/call","params":{"name":"recommend_action","arguments":{"task":"reload"}}}')
printf '%s\n' "$out" | grep 'count.*1' >/dev/null
printf '%s\n' "$out" | grep 'reload-good' >/dev/null
if printf '%s\n' "$out" | grep 'reload-counter\|reload-retired\|reload-unknown\|reload-duplicate\|reload-unknown-scope\|reload-duplicate-key' >/dev/null; then exit 1; fi

duplicate_data="$tmp/duplicate-experience-data"
mkdir -p "$duplicate_data"
printf '%s\n' '{"id":"immutable-duplicate","kind":"experience","project":"p","task":"first fact","action":"a1","outcome":"success","evidence":"e1"}' > "$duplicate_data/experiences.jsonl"
printf '%s\n' '{"id":"immutable-duplicate","kind":"experience","project":"p","task":"second fact","action":"a2","outcome":"failure","evidence":"e2"}' >> "$duplicate_data/experiences.jsonl"
out=$(call_data "$duplicate_data" '{"jsonrpc":"2.0","id":477,"method":"tools/call","params":{"name":"find_experiences","arguments":{"query":"first fact"}}}')
printf '%s\n' "$out" | grep 'first fact' >/dev/null
if printf '%s\n' "$out" | grep 'second fact' >/dev/null; then exit 1; fi

collision_data="$tmp/generated-id-collision-data"
mkdir -p "$collision_data"
collision_epoch=$(date +%s)
printf '%s\n' "{\"id\":\"exp-$collision_epoch-2\",\"kind\":\"experience\",\"project\":\"collision\",\"task\":\"collision seed\",\"action\":\"seed\",\"outcome\":\"success\",\"evidence\":\"seed\"}" > "$collision_data/experiences.jsonl"
out=$(call_data "$collision_data" '{"jsonrpc":"2.0","id":478,"method":"tools/call","params":{"name":"record_experience","arguments":{"project":"collision","task":"collision generated","action":"generate","outcome":"success","evidence":"generated"}}}')
printf '%s\n' "$out" | grep 'Recorded observed experience' >/dev/null
[ "$(wc -l < "$collision_data/experiences.jsonl")" -eq 2 ]

response_data="$tmp/response-bound-data"
mkdir -p "$response_data"
response_text=$(awk 'BEGIN { for (i = 1; i <= 6000; i++) printf "r" }')
n=1
while [ "$n" -le 20 ]; do
    call_data "$response_data" "{\"jsonrpc\":\"2.0\",\"id\":$((480 + n)),\"method\":\"tools/call\",\"params\":{\"name\":\"record_experience\",\"arguments\":{\"experience_id\":\"response-$n\",\"task\":\"response bound\",\"action\":\"$response_text\",\"outcome\":\"$response_text\",\"evidence\":\"$response_text\"}}}" >/dev/null
    n=$((n + 1))
done
out=$(call_data "$response_data" '{"jsonrpc":"2.0","id":501,"method":"tools/call","params":{"name":"find_experiences","arguments":{"query":"response bound","limit":20}}}')
printf '%s\n' "$out" | grep 'truncated.*bytes' >/dev/null

malformed_lock_data="$tmp/malformed-lock-data"
mkdir -p "$malformed_lock_data"
printf '%s\n' 'not-a-pid' > "$malformed_lock_data/.owlgrowth.lock"
out=$(call_data "$malformed_lock_data" '{"jsonrpc":"2.0","id":476,"method":"ping"}')
printf '%s\n' "$out" | grep '"result":{}' >/dev/null
[ ! -e "$malformed_lock_data/.owlgrowth.lock" ]

concurrent_data="$tmp/concurrent-data"
n=1
while [ "$n" -le 4 ]; do
    printf '%s\n' '{"jsonrpc":"2.0","id":475,"method":"tools/call","params":{"name":"record_experience","arguments":{"task":"concurrent","action":"write","outcome":"success","evidence":"process"}}}' |
        OWL_GROWTH_DATA_DIR="$concurrent_data" "$root/bin/owlgrowth-mcp" > "$tmp/concurrent-$n.out" &
    n=$((n + 1))
done
wait
out=$(call_data "$concurrent_data" '{"jsonrpc":"2.0","id":476,"method":"tools/call","params":{"name":"find_experiences","arguments":{"query":"concurrent","limit":20}}}')
printf '%s\n' "$out" | grep 'count.*4' >/dev/null

observation_data="$tmp/concurrent-observations"
call_data "$observation_data" '{"jsonrpc":"2.0","id":477,"method":"tools/call","params":{"name":"record_experience","arguments":{"experience_id":"concurrent-exp","task":"concurrent observations","action":"seed","outcome":"success","evidence":"seed"}}}' >/dev/null
call_data "$observation_data" '{"jsonrpc":"2.0","id":478,"method":"tools/call","params":{"name":"record_adaptation","arguments":{"adaptation_id":"concurrent-adaptation","guidance":"observe safely","scope":{"task":"concurrent observations"},"source_experience_ids":["concurrent-exp"]}}}' >/dev/null
n=1
while [ "$n" -le 4 ]; do
    printf '%s\n' '{"jsonrpc":"2.0","id":479,"method":"tools/call","params":{"name":"observe_adaptation","arguments":{"adaptation_id":"concurrent-adaptation","project":"current","task":"concurrent observations","result":"success","evidence":"parallel"}}}' |
        OWL_GROWTH_DATA_DIR="$observation_data" "$root/bin/owlgrowth-mcp" > "$tmp/observation-$n.out" &
    n=$((n + 1))
done
wait
out=$(call_data "$observation_data" '{"jsonrpc":"2.0","id":480,"method":"tools/call","params":{"name":"review_adaptation","arguments":{"adaptation_id":"concurrent-adaptation"}}}')
printf '%s\n' "$out" | grep 'success.*4' >/dev/null

printf '%s\n' 'OwlGrowth tests passed.'
