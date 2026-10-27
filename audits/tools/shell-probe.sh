#!/usr/bin/env bash
# Load only the request helper. Stub curl; demonstrate eval using a stdout marker.
set -u
case "$1" in admin-cli.sh|passenger-cli.sh) ;; *) printf 'Choose a historical CLI filename.\n' >&2; exit 1;; esac
audit_root=$(cd "$(dirname "$0")/../.." && pwd)
source <(git -C "$audit_root" show "7d56d4e:$1" | sed -n '/^invoke_api() {/,/^}/p')
curl() { printf 'AUDIT_CURL_STUB\n'; }
invoke_api 'https://example.invalid/; printf AUDIT_EVAL_MARKER' GET '' false
