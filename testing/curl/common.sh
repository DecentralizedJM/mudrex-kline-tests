#!/usr/bin/env bash
# Common helpers for Mudrex API curl tests.
# Usage: source testing/curl/common.sh

set -euo pipefail

BASE_URL="${MUDREX_BASE_URL:-https://trade.mudrex.com/fapi/v1}"

if [[ -z "${MUDREX_API_SECRET:-}" ]]; then
  if [[ -f ".env" ]]; then
    # shellcheck disable=SC1091
    source .env
  fi
fi

if [[ -z "${MUDREX_API_SECRET:-}" ]]; then
  echo "Error: MUDREX_API_SECRET is not set. Export it or create a .env file." >&2
  exit 1
fi

api_get() {
  local path="$1"
  shift || true
  curl -sS -w "\n__HTTP_STATUS__:%{http_code}" \
    -X GET "${BASE_URL}${path}" \
    -H "X-Authentication: ${MUDREX_API_SECRET}" \
    "$@"
}

api_post() {
  local path="$1"
  local data="$2"
  shift 2 || true
  curl -sS -w "\n__HTTP_STATUS__:%{http_code}" \
    -X POST "${BASE_URL}${path}" \
    -H "Content-Type: application/json" \
    -H "X-Authentication: ${MUDREX_API_SECRET}" \
    -d "${data}" \
    "$@"
}

api_patch() {
  local path="$1"
  local data="$2"
  curl -sS -w "\n__HTTP_STATUS__:%{http_code}" \
    -X PATCH "${BASE_URL}${path}" \
    -H "Content-Type: application/json" \
    -H "X-Authentication: ${MUDREX_API_SECRET}" \
    -d "${data}"
}

api_delete() {
  local path="$1"
  curl -sS -w "\n__HTTP_STATUS__:%{http_code}" \
    -X DELETE "${BASE_URL}${path}" \
    -H "X-Authentication: ${MUDREX_API_SECRET}"
}
