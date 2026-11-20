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
PORT="$INTERNAL_PORT" "$@" &
APP=$!
if ! node /railway-bootstrap.js "$INTERNAL_PORT"; then
  kill "$APP" 2>/dev/null
  fail "bootstrap failed, see the lines above"
fi
kill "$APP" 2>/dev/null
wait "$APP" 2>/dev/null
echo "[railway] bootstrap done, starting on :$REAL_PORT"
PORT="$REAL_PORT" exec "$@"
