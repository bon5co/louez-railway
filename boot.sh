#!/bin/sh
# Railway boot for Louez.
#
# Refuses to start without a strong owner password, an auth secret and the database and storage settings. Starts the server on a
# loopback port, registers the owner and closes public registration (bootstrap.js, idempotent), stops it, and starts the real
# server on Railway's injected PORT.
set -u
fail() { echo "[railway] $1" >&2; exit 1; }
[ -n "${ADMIN_EMAIL:-}" ] || fail "ADMIN_EMAIL is not set"
[ -n "${ADMIN_PASSWORD:-}" ] || fail "ADMIN_PASSWORD is not set; refusing to start a rental platform with no owner login"
[ "${#ADMIN_PASSWORD}" -ge 12 ] || fail "ADMIN_PASSWORD must be at least 12 characters"
AUTH_SECRET="${AUTH_SECRET:-}"
[ "${#AUTH_SECRET}" -ge 32 ] || fail "AUTH_SECRET must be set and at least 32 characters"
[ -n "${DATABASE_URL:-}" ] || fail "DATABASE_URL is not set"
[ -n "${S3_ENDPOINT:-}" ] || fail "S3_ENDPOINT is not set"
[ -n "${S3_ACCESS_KEY_ID:-}" ] || fail "S3_ACCESS_KEY_ID is not set"
[ -n "${S3_SECRET_ACCESS_KEY:-}" ] || fail "S3_SECRET_ACCESS_KEY is not set"
[ -n "${AUTH_URL:-}" ] || fail "AUTH_URL is not set"
case "${PORT:=8080}" in ''|*[!0-9]*) fail "PORT must be a number, got '$PORT'";; esac
export AUTH_SECRET
REAL_PORT="$PORT"
INTERNAL_PORT=5999
echo "[railway] Louez on :$REAL_PORT as $AUTH_URL, uid=$(id -u); bootstrapping on 127.0.0.1:$INTERNAL_PORT first"
# Two containers can start against one empty database at the same moment (a platform that deploys a service twice while it is
# created). Upstream's migrator then sees the other container's half-built schema and exits, and the server never listens. Wait
# for the server to stay up while the owner is registered; if it dies first, the other container has finished the schema by now,
# so start again (the migrator and the owner registration are both idempotent).
attempt=0
while :; do
  attempt=$((attempt + 1))
  PORT="$INTERNAL_PORT" "$@" &
  APP=$!
  node /railway-bootstrap.js "$INTERNAL_PORT" &
  BS=$!
  died=""
  while kill -0 "$BS" 2>/dev/null; do
    if ! kill -0 "$APP" 2>/dev/null; then
      died=1
      kill "$BS" 2>/dev/null
      break
    fi
    sleep 1
  done
  if [ -n "$died" ]; then
    wait "$BS" 2>/dev/null
    wait "$APP" 2>/dev/null
    [ "$attempt" -lt 6 ] || fail "server exited during bootstrap $attempt times, see the lines above"
    echo "[railway] server exited during bootstrap (attempt $attempt); retrying in 15s"
    sleep 15
    continue
  fi
  if ! wait "$BS"; then
    kill "$APP" 2>/dev/null
    fail "bootstrap failed, see the lines above"
  fi
  break
done
kill "$APP" 2>/dev/null
wait "$APP" 2>/dev/null
echo "[railway] bootstrap done, starting on :$REAL_PORT"
PORT="$REAL_PORT" exec "$@"
