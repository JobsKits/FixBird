#!/bin/sh
set -eu

attempt=1
max_attempts=60
while ! /app/migrate; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "TiDB migration did not become ready after $max_attempts attempts." >&2
    exit 1
  fi
  echo "TiDB is not ready; retrying migration ($attempt/$max_attempts)." >&2
  attempt=$((attempt + 1))
  sleep 3
done

exec /app/api
