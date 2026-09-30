#!/bin/sh
# Reject invalid development budgets before data access, transport or model calls.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for assignment in BUDGET_MAX_NEW=0 BUDGET_MAX_NEW=8193 BUDGET_MAX_NEW=-1 BUDGET_MAX_NEW=1.5 BUDGET_CONTEXT=8192 BUDGET_CONTEXT=65536 BUDGET_CONTEXT=abc BUDGET_TIMEOUT_MS=0 BUDGET_TIMEOUT_MS=600001 BUDGET_TIMEOUT_MS=1000.5; do
    status=0
    env "$assignment" "$repo/scripts/run-native-budget" > /dev/null 2>&1 || status=$?
    [ "$status" -eq 2 ] || { echo "invalid configuration accepted: $assignment ($status)"; exit 1; }
done
echo 'PASS development budget argument checks'
