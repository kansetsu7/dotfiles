#!/usr/bin/env bash
#
# bootstrap script, assumed to be run as root
#
# to used it as vagrant provision shell script, invoke with parameter 'vagrant'
#

source /etc/os-release

if [[ "$NAME" = "Ubuntu" && "$VERSION_ID" = "14.04" ]]; then
  # update package list
  sed -i 's/archive\.ubuntu\.com/ftp\.cuhk\.edu\.hk\/pub\/Linux/g' /etc/apt/sources.list
  sed -i 's/security\.ubuntu\.com/ftp\.cuhk\.edu\.hk\/pub\/Linux/g' /etc/apt/sources.list
  apt-get update

  apt-get -y install python-software-properties

  # setup proper locale
  locale-gen en_HK.utf8 zh_TW.utf8
  update-locale LC_ALL=en_HK.utf8 LANG=en_HK.utf8
  export LANG=en_HK.UTF8

  # install required packages
  apt-get -y install build-essential git-core git-extras tig wget curl htop tmux \
    rake exuberant-ctags vim-gtk silversearcher-ag zsh ntp
  apt-get -y install nginx postgresql-9.3 postgresql-contrib-9.3 redis-server
  apt-get -y install bison openssl libssl-dev libxslt1.1 libxslt1-dev \
    libxml2 libxml2-dev libffi-dev libyaml-dev autoconf \
    libc6-dev libreadline6-dev zlib1g zlib1g-dev \
    ruby-dev libruby2.0 libsqlite3-dev libpq-dev
  apt-get -y install pdftk poppler-utils openjdk-7-jdk

elif [[ "$NAME" = "Ubuntu" && "$VERSION_ID" = "12.04" ]]; then
  # update package list
  sed -i 's/archive\.ubuntu\.com/ftp\.cuhk\.edu\.hk\/pub\/Linux/g' /etc/apt/sources.list
  sed -i 's/security\.ubuntu\.com/ftp\.cuhk\.edu\.hk\/pub\/Linux/g' /etc/apt/sources.list
  apt-get update

  apt-get -y install python-software-properties

  # setup proper locale
  locale-gen en_HK.utf8
  update-locale LC_ALL=en_HK.utf8 LANG=en_HK.utf8
  export LANG=en_HK.UTF8

  # get latest repository
  add-apt-repository -y ppa:git-core/ppa
  add-apt-repository -y ppa:fcwu-tw/ppa
  add-apt-repository -y ppa:kalakris/tmux

  # get latest postgres repository
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
  echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > /etc/apt/sources.list.d/postgresql.list

  apt-get update

  # install required packages
  apt-get -y install build-essential git-core tig wget curl htop tmux \
    rake exuberant-ctags vim-gtk silversearcher-ag zsh ntp
  apt-get -y install nginx postgresql-9.3 postgresql-contrib-9.3 redis-server
  apt-get -y install bison openssl libssl-dev libxslt1.1 libxslt1-dev \
    libxml2 libxml2-dev libffi-dev libyaml-dev libxslt-dev autoconf \
    libc6-dev libreadline6-dev zlib1g zlib1g-dev \
    ruby-dev libopenssl-ruby libsqlite3-dev libpq-dev
  apt-get -y install pdftk poppler-utils openjdk-7-jdk

elif [[ "$NAME" = "ArchLinux" ]]; then
  # update package list
  pacman -Sy
  pacman --noconfirm --needed -S base-devel git tig wget curl htop tmux \
    ruby gvim ctags ack zsh the_silver_searcher
  pacman --noconfirm --needed -S bison openssl libxslt libxml2 libyaml libffi \
    autoconf readline zlib

fi

#
# install chruby
#
if [ ! -d ~/src/chruby ]; then
  git clone git://github.com/postmodern/chruby.git ~/src/chruby
  cd ~/src/chruby
  make install
fi

#
# install ruby-install
#
if [ ! -d ~/src/ruby-install ]; then
  git clone git://github.com/postmodern/ruby-install.git ~/src/ruby-install
  cd ~/src/ruby-install
  make install
fi

#
# install git-extras
#
if [ ! -d ~/src/git-extras ]; then
  git clone git://github.com/tj/git-extras ~/src/git-extras
  cd ~/src/git-extras
  git checkout $(git describe --tags $(git rev-list --tags --max-count=1))
  make install
fi


if [[ $1 == "vagrant" ]]; then
  # set local timezone
  echo 'Asia/Hong_Kong' | tee /etc/timezone
  dpkg-reconfigure --frontend noninteractive tzdata

  # install personalize development environment
  su -l -c '[ ! -d ~/.dotfiles ] && git clone git://github.com/szetobo/dotfiles.git ~/.dotfiles; ~/.dotfiles/run.sh install' vagrant
  chsh -s /bin/zsh vagrant

  # install phantomjs, dependency of rails integration test
  cd /tmp
  wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2
  tar xvjf phantomjs-1.9.7-linux-x86_64.tar.bz2
  mv phantomjs-1.9.7-linux-x86_64 /usr/local/share/phantomjs
  ln -s /usr/local/share/phantomjs/bin/phantomjs /usr/local/bin/phantomjs

  # install nodejs
  cd /tmp
  wget http://nodejs.org/dist/v0.10.28/node-v0.10.28-linux-x64.tar.gz
  cd /usr/local && tar --strip-components 1 -xzf /tmp/node-v0.10.28-linux-x64.tar.gz
fi

exit 0

