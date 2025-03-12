# Define path
export PROJECT_PATH=/proj
export DOTFILE_PATH=/root/.dotfiles
export NERV_PREFIX=nerv_

export PGUSER=psql

# shortcut on pointing diff compose file and using lazydocker
ld() {
  case "${1:-not_specify}" in
    not_specify)
      lazydocker
      ;;
    hq)
      lazydocker -f "/current/hq/compose.yml"
      ;;
    hk|ck|sg|ave_ck)
      lazydocker -f "/current/sites/nerv_by_site_code/$1/compose.yml"
      ;;
    aba)
      lazydocker -f "/current/sites/amoeba/compose.yml"
      ;;
    *)
      if [[ -f "/current/sites/$1/compose.yml" ]]; then
        lazydocker -f "/current/sites/$1/compose.yml"
      else
       echo "docker compose file not exist, please try again!"
      fi
      ;;
  esac
}
