#!/usr/local/bin/zsh -e
echo 'yooo'

# USAGE EXAMPLE
#
# - Dump database
#
#   - magi_db
#
# - Create snapshot of current database
#
#   - magi_db s
#   - magi_db snapshot
#
# - Show dump directory
#
#   - magi_db ls

db='magi_development'
src='magi_masked.custom'

force_drop=1
date_fmt='%3.3s %2.2s' # Dec 13 15:06
local_date_fmt=$date_fmt
[[ "${${LC_ALL:0:2}# }" == 'zh' || "${${LC_TIME:0:2}# }" == 'zh' ]] && local_date_fmt='%3.3s%2.2s' # 11月 6 13:40


dump_dir=~/tmp/dumpdb/${db}
mkdir -p $dump_dir

if [[ $# > 0 ]]; then
  case "$1" in
    s|snapshot)
      shift
      if [[ $# > 0 ]]; then
        filename="snapshot-$*"
        old_filename=$filename

        if [[ -f $dump_dir/$filename ]]; then
          echo "File '$filename' already exist"
          filename="$filename-$(date +%y-%m-%d_%H:%M:%S)"
        fi
        echo -n "Make snapshot of db as '$filename'? (y/n/o)"
      else
        filename="snapshot-$(date +%y-%m-%d_%H:%M:%S)"
        echo -n "Make snapshot of db? (y/n)"
      fi

      read sure
      if [[ $sure == "y" ]]; then
        pg_dump $db --format=custom --no-owner > "$dump_dir/$filename" && echo 'Done.' && exit 0
      elif [[ $sure == "o" ]]; then
        pg_dump $db --format=custom --no-owner > "$dump_dir/$old_filename" && echo 'Done.' && exit 0
      fi
      ;;
    ll)
      ls -alh $dump_dir
      echo "\nIn $dump_dir"
      exit 0
      ;;
    cd|ls)
      ls $dump_dir
      echo "\nIn $dump_dir"
      exit 0
  esac
fi

if (ls $dump_dir/*) 1> /dev/null 2>&1 ; then
  # Define ignore item here
  ignore="$db.masked"

  items=("${(f)$(\
    ls -thgobB -1 $dump_dir \
        --ignore="$ignore" \
        --time-style=+%b%t%-e%t%H:%M |\
    awk '{ print substr($0, index($0,$3)) }' |\
    awk '{FPAT="(\\S|\\\\ )+"; printf "%%F{blue}%2.2s%%f '$local_date_fmt' %s %4.4s %2.2s) %s\n",\
          FNR - 1, $2, $3, $4, $1, FNR - 1, $NF}' |\
    tail -n +2\
  )}")

  echo "\nReplace $db with:\n"
  print -lP $items
  echo -n "\nchoose: "
  read choice

  for item in $items; do
    if [[ $choice == "${${item:8:2}# }" ]]; then
      filename=$(echo "${item:13}" | sed 's/.\+[0-9]) //g')
      echo "\nRestore from '$filename' ..."

      if [[ -n "$force_drop" ]]; then
        psql --quiet -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) \
          FROM pg_stat_activity \
          WHERE pg_stat_activity.datname = '$db' \
          AND pid <> pg_backend_pid();" > /dev/null

        psql -d postgres -c "  drop database $db" > /dev/null
        psql -d postgres -c "create database $db" > /dev/null
        pg_restore --no-owner -d $db "$dump_dir/${filename//\\ / }" -j $(nproc) --exit-on-error
        echo 'Done.'
      else
        # TODO: remove strategy below (unused), we do -c (clean) on our own
        pg_restore -O -c -j $(nproc) -d $db "$dump_dir/${filename//\\ / }" && echo 'Done.'
      fi
    fi
  done
else
  echo 'No dump file available.'
fi
