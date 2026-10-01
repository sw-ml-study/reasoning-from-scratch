#!/bin/sh
# Synthetic trace proves window mapping and exclusion of nested runtime wrappers.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sqlite3 "$tmp/trace.sqlite" <<'SQL'
CREATE TABLE StringIds(id INTEGER,value TEXT);
INSERT INTO StringIds VALUES(1,'cuMemcpyDtoHAsync_v2'),(2,'cuLaunchKernel'),(3,'cudaLaunchKernel_v7000'),(4,'cuMemAllocAsync'),(5,'cuMemFreeAsync');
CREATE TABLE CUPTI_ACTIVITY_KIND_RUNTIME(start INTEGER,end INTEGER,correlationId INTEGER,nameId INTEGER);
CREATE TABLE CUPTI_ACTIVITY_KIND_MEMCPY(start INTEGER,end INTEGER,correlationId INTEGER,bytes INTEGER,copyKind INTEGER);
CREATE TABLE CUPTI_ACTIVITY_KIND_KERNEL(start INTEGER,end INTEGER);
CREATE TABLE ord(n INTEGER);
WITH RECURSIVE numbers(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM numbers WHERE n<51) INSERT INTO ord SELECT n FROM numbers;
INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME SELECT n*10000000+7900000,n*10000000+9100000,n,1 FROM ord;
INSERT INTO CUPTI_ACTIVITY_KIND_MEMCPY SELECT n*10000000+8000000,n*10000000+9000000,n,607744,2 FROM ord;
INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL SELECT n*10000000+2000000,n*10000000+3000000 FROM ord;
INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME SELECT n*10000000+1200000,n*10000000+1400000,100+n,2 FROM ord;
INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME SELECT n*10000000+1100000,n*10000000+1500000,200+n,3 FROM ord;
INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME SELECT n*10000000+500000,n*10000000+600000,300+n,4 FROM ord;
INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME SELECT n*10000000+700000,n*10000000+800000,400+n,5 FROM ord;
SQL
"$repo/scripts/analyze-cuda-trace" "$tmp/trace.sqlite" > "$tmp/rows"
[ "$(wc -l < "$tmp/rows")" -eq 48 ]
# Validate every numeric field with SQLite JSON, without introducing jq into the gate.
result=$(sqlite3 "$tmp/check.sqlite" <<SQL
CREATE TABLE rows(value TEXT);
.import $tmp/rows rows
SELECT CASE WHEN count(*)=48 AND min(json_extract(value,'$.kernels'))=1 AND max(json_extract(value,'$.kernels'))=1 AND min(json_extract(value,'$.window_ms'))=10 AND max(json_extract(value,'$.window_ms'))=10 AND min(json_extract(value,'$.launch_api_ms'))=0.2 AND max(json_extract(value,'$.launch_api_ms'))=0.2 AND min(json_extract(value,'$.kernel_span_ms'))=1 AND max(json_extract(value,'$.kernel_span_ms'))=1 AND min(json_extract(value,'$.allocation_api_ms'))=0.2 AND max(json_extract(value,'$.allocation_api_ms'))=0.2 AND count(DISTINCT json_extract(value,'$.group_index'))=3 THEN 'PASS' ELSE 'FAIL' END FROM rows;
SQL
)
[ "$result" = PASS ] || { echo 'wrong trace accounting' >&2; exit 1; }
sqlite3 "$tmp/trace.sqlite" 'DELETE FROM CUPTI_ACTIVITY_KIND_MEMCPY WHERE correlationId=0;'
if "$repo/scripts/analyze-cuda-trace" "$tmp/trace.sqlite" > /dev/null 2>&1; then
    echo 'mismatched trace accepted' >&2; exit 1
fi
printf 'PASS CUDA trace fixture and workload rejection\n'
