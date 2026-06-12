#!/usr/bin/env bash
set -e
#
# stop_pg10_if_idle.sh — run a project's `docker compose down` (passed as args),
# then remove the shared postgres_10 if that left NO pg10-dependent project
# (amoeba/angel/cam) running.
#
# Counterpart to ensure_pg10.sh and hooked to lazydocker's `down`/`downWithVolumes`
# templates (the Shift+`D` "down project" key — NOT lowercase `d`, which lazydocker
# hardcodes to `docker-compose rm` and does not route through these templates):
# starting a dependent project brings pg10 up; downing the LAST running dependent
# removes pg10 so it isn't left around idle.
#
# Mechanism-independent: it snapshots which dependents are running before and
# after the down (which is passed verbatim as arguments and run as-is), so it
# doesn't matter how lazydocker addresses the project (-f / -p / COMPOSE_FILE).
# It stops pg10 ONLY when the down takes the dependent set from "some running"
# to "none" — so downing an unrelated project, or downing one dependent while
# another is still up, never touches pg10.

DEPS="amoeba angel cam"

deps_running() {
  local p out=""
  for p in $DEPS; do
    if [ -n "$(docker ps -q \
                --filter "label=com.docker.compose.project=$p" \
                --filter status=running 2>/dev/null)" ]; then
      out="$out $p"
    fi
  done
  printf '%s' "$out"
}

before="$(deps_running)"

# Run the down command lazydocker handed us.
"$@"

after="$(deps_running)"

# Act only when this down emptied the dependent set.
if [ -n "$before" ] && [ -z "$after" ]; then
  compose_file=""
  for c in \
    "/current/extra/compose.yml" \
    "${PROJECT_PATH:+$PROJECT_PATH/vm/docker-dev/extra/compose.yml}" \
    "$HOME/proj/vm/docker-dev/extra/compose.yml" \
    "$HOME/project/vm/docker-dev/extra/compose.yml"; do
    if [ -n "$c" ] && [ -f "$c" ]; then compose_file="$c"; break; fi
  done

  if [ -n "$compose_file" ] && [ -n "$(docker ps -q \
        --filter 'label=com.docker.compose.project=extra' \
        --filter 'label=com.docker.compose.service=postgres_10' \
        --filter status=running 2>/dev/null)" ]; then
    echo ">>> [pg10] no pg10-dependent project left running — removing postgres_10..."
    # `rm --stop --force` is scoped to postgres_10 only: it stops then removes
    # that one container, leaving the rest of the `extra` project (grafana/loki/
    # etc.) and the network intact. The next `u` recreates it via ensure_pg10.sh.
    docker compose -f "$compose_file" rm --stop --force postgres_10 || true
  fi
fi
