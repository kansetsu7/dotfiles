#!/usr/bin/env bash
set -e
#
# ensure_pg10.sh — make sure the shared Postgres 10 service is running, then
# run the command passed as arguments.
#
# amoeba / angel / cam all connect to the Postgres 10 database defined in
# docker-dev's extra/compose.yml (service: postgres_10), which lives in a
# separate compose project ("extra"). lazydocker's up/upService command
# templates call this so pressing `u` starts the DB before a project starts.
#
# Only those three projects need pg10, so — like stop_pg10_if_idle.sh, which
# keys off the same DEPS set — this script first resolves the compose project
# being started and ensures pg10 ONLY for a dependent. Starting any other
# project (e.g. the `extra` project itself, or an unrelated service) skips the
# pg10 check entirely and just runs the command. If the project can't be
# determined it fails open (ensures pg10) so a dependent is never left without
# its DB.
#
# This script is SHARED by both OS configs (like ~/.zshrc_helper); each per-OS
# config.yml (configs/docker, configs/mac) references it by the OS-specific
# absolute path. It locates extra/compose.yml itself, so it needs no per-OS
# copy. lazydocker runs templates via argv (no shell), so the project's compose
# command is passed as ARGS here and exec'd, rather than chained with `&&`.
#
# Idempotent: if postgres_10 is already running it just exec's the command.

DEPS="amoeba angel cam"

# Resolve the compose project being started. lazydocker hands us
# `<docker compose ...> up -d [service]`; the invocation prefix is everything
# before the `up` verb. Re-running it as `... config` lets docker compose apply
# its own project-name resolution (-p / COMPOSE_PROJECT_NAME / top-level name /
# dir basename) and print the result as a top-level, unindented `name:` line.
prefix=()
for a in "$@"; do
  [ "$a" = "up" ] && break
  prefix+=("$a")
done
project=""
if [ "${#prefix[@]}" -gt 0 ]; then
  project="$("${prefix[@]}" config 2>/dev/null \
    | sed -n 's/^name:[[:space:]]*//p' | tr -d '"' | head -n1)"
fi

# Ensure pg10 for a dependent, or when the project is unknown (fail open).
# Skip outright for any other resolved project.
case " $DEPS " in
  *" $project "*) ;;
  *)
    if [ -n "$project" ]; then
      echo ">>> [ensure_pg10] '$project' does not need pg10 — skipping check."
      exec "$@"
    fi
    ;;
esac

# Locate docker-dev's extra/compose.yml across environments (container vs mac).
compose_file=""
for c in \
  "/current/extra/compose.yml" \
  "${PROJECT_PATH:+$PROJECT_PATH/vm/docker-dev/extra/compose.yml}" \
  "$HOME/proj/vm/docker-dev/extra/compose.yml" \
  "$HOME/project/vm/docker-dev/extra/compose.yml"; do
  if [ -n "$c" ] && [ -f "$c" ]; then
    compose_file="$c"
    break
  fi
done

if [ -z "$compose_file" ]; then
  echo ">>> [ensure_pg10] WARNING: extra/compose.yml not found; skipping pg10 check." >&2
elif [ -z "$(docker ps -q \
              --filter 'label=com.docker.compose.project=extra' \
              --filter 'label=com.docker.compose.service=postgres_10' \
              --filter status=running)" ]; then
  echo ">>> [ensure_pg10] postgres_10 not running — starting it..."
  docker compose -f "$compose_file" up -d postgres_10 || true

  cid="$(docker compose -f "$compose_file" ps -q postgres_10 2>/dev/null || true)"
  if [ -n "$cid" ]; then
    echo ">>> [ensure_pg10] waiting for postgres_10 to accept connections..."
    for _ in $(seq 1 30); do
      if docker exec "$cid" pg_isready -q 2>/dev/null; then
        echo ">>> [ensure_pg10] postgres_10 ready."
        break
      fi
      sleep 1
    done
  fi
fi

# Run the command lazydocker handed us (the project's `docker compose up`).
exec "$@"
