#!/usr/bin/env bash
# Type-check all .lean files in the dataset using the package environment.
# Run from the repo root after: lake exe cache get
set -euo pipefail

PASS=0; FAIL=0
while IFS= read -r f; do
  if lake env lean "$f" > /dev/null 2>&1; then
    echo "ok  $f"
    ((PASS++))
  else
    echo "ERR $f"
    lake env lean "$f" 2>&1 | sed 's/^/    /'
    ((FAIL++))
  fi
done < <(find dataset -name "*.lean")

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
