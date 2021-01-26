#!/usr/bin/env bash

ruby_version='2.6.5'
java_version='corretto-8.232.09.1'
nodejs_version='14.4.0'

set -e

echo 'Starting setup-magi...'
echo

# 註：若 ssh config 不正確，這裡會卡住直到 timeout
[[ ! -d ~/magi ]] && git clone git@github.com:kansetsu7/magi.git ~/magi

[[ -z `asdf plugin-list | grep 'ruby'`        ]]  && asdf plugin-add ruby
[[ -z `asdf list ruby   | grep $ruby_version` ]]  && asdf plugin-update ruby && asdf install ruby $ruby_version

[[ -z `asdf plugin-list | grep 'java'`        ]]  && asdf plugin-add java
if [[ -z `asdf list java | grep $java_version` ]]; then
  if [[ -z $(dpkg-query -W -f='${Status}' jq 2>/dev/null | grep 'ok installed') ]]; then
    sudo apt install jq -y
  fi
  asdf install java $java_version
fi

[[ -z `asdf plugin-list | grep 'nodejs'`  ]]  && asdf plugin-add nodejs
if [[ -z `asdf list nodejs | grep $nodejs_version` ]]; then
  bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
  asdf install nodejs $nodejs_version
fi

cd ~/magi

cp .env.sample .env
for f in config/*.sample; do cp "$f" "${f%.sample}"; done

asdf local ruby $ruby_version
asdf local java $java_version
asdf local nodejs $nodejs_version

if [[ ! -z `ruby -v | grep $ruby_version` ]]; then
  gem install bundler
  bundle install
  # bundle exec thor setup:all
  bundle exec rake db:setup
  # bundle exec rake tmp:create
  echo "You are all set! Welcome to Magi!"
else
  echo "Aborted."
  echo "Didn't correctly use user ruby."
  echo "Please fix and try again."
fi
