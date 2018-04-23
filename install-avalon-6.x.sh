#!/bin/bash

# This script takes a freshly provisioned 16.04 cloud instance,
# and runs the install steps needed to run avalon in docker.
# Make sure that you are allowing these outgoing ports on your instance
# (I restrict mine to U of A traffic):
#   3000 (webserver will run on this)
#   8880, 1935 (streaming)
#   8080 (if you want to look at matterhorn web interface)
#   8984 (if you want to look at fedora web interface)
#   8983 (if you want to look at solr web interface)

RUBY_VERSION='2.4'
BUNDLER_VERSION='1.14'
AVALON_REPO='https://github.com/avalonmediasystem/avalon'
AVALON_BRANCH='develop'
SRC_DIR=$HOME/gitwork
AVALON_DIR=$SRC_DIR/avalon
MASTERFILES=$AVALON_DIR/masterfiles

GIT_USER='Chris Want'
GIT_EMAIL='cjwant@gmail.com'
GIT_EDITOR=emacs

# BIND_NETWORK='192.168'

main() {
  setup_hostname || exit
  install_packages || exit
  install_docker || exit
  install_ruby || exit
  install_sources || exit
  configure_sources || exit
  launch_services_www_docker || exit
}

setup_hostname() {
  # sudo complains that hostname isn't set, so we set it
  hostname=`hostname`
  grep '127.0.1.1.*'$hostname /etc/hosts && return 0
  sudo sh -c "echo 127.0.1.1 $hostname >> /etc/hosts" || exit 1
}

install_packages() {
  sudo apt-get -y update || exit 1
  sudo apt-get -y dist-upgrade || exit 1
  sudo apt-get install -y \
    tmux \
    emacs-nox \
    yaml-mode \
    lynx \
    htop \
    git \
    phantomjs \
    mediainfo \
    ffmpeg \
    libmysqlclient-dev \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    cmake \
    nodejs \
    libpq-dev \
    python3-pip \
    libyazpp-dev \
    zlib1g-dev \
    libyaml-dev \
    libsqlite3-dev \
    sqlite3 \
    autoconf \
    libgmp-dev \
    libgdbm-dev \
    libncurses5-dev \
    automake \
    libtool \
    bison \
    pkg-config \
    libffi-dev \
    libgmp-dev \
    libreadline6-dev \
    libssl-dev || exit 1
}

install_docker() {
  (sudo apt-key list | grep 0EBFCD87) || \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo apt-key add - || exit 1
  (apt-cache policy | grep docker) || \
    sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" || exit 1
  sudo apt-get -y update || exit 1
  sudo apt-get -y install docker-ce || exit 1
  which docker-compose || pip3 install docker-compose || exit 1
  sudo service docker start || exit 1
  # Note, probably need to log in and out for the next one to stick
  sudo adduser $USER docker || exit 1
}

install_ruby() {
  # After this runs, if you want to use ruby/bundler you can either login
  # again, or run in the current shell by doing: source $HOME/.rvm/scripts/rvm
  cd $HOME
  [ -d .rvm ] || gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
  [ -d .rvm ] || \curl -sSL https://get.rvm.io | bash -s stable
  source $HOME/.rvm/scripts/rvm
  rvm install $RUBY_VERSION
  gem install bundler -v $BUNDLER_VERSION
}

install_sources() {
  git config --global user.email "$GIT_EMAIL"
  git config --global user.name "$GIT_USER"
  git config --global core.editor "$GIT_EDITOR"

  mkdir -p $SRC_DIR
  cd $SRC_DIR

  [ -d avalon ] || git clone $AVALON_REPO || exit
  cd $AVALON_DIR
  git checkout $AVALON_BRANCH || exit
}

configure_sources() {
  cd $AVALON_DIR

  cp config/controlled_vocabulary.yml.example \
     config/controlled_vocabulary.yml

  EXT_IP=`curl -4 icanhazip.com`

  #CONFIG_FILE="config/settings/development.local.yml"
  #echo 'ffmpeg:' >> $CONFIG_FILE
  #echo "  path: '/usr/bin/ffmpeg'" >> $CONFIG_FILE
  #echo 'matterhorn:' >> $CONFIG_FILE
  #echo "  media_path: '/masterfiles'" >> $CONFIG_FILE
  #echo "streaming:" >> $CONFIG_FILE
  #echo "  host: '$EXT_IP'" >> $CONFIG_FILE

  COMPOSE_OVERRIDES="docker-compose.override.yml"
  echo "version: '2'" >> $COMPOSE_OVERRIDES
  echo "services:" >> $COMPOSE_OVERRIDES
  echo "  avalon:" >> $COMPOSE_OVERRIDES
  echo "    environment:" >> $COMPOSE_OVERRIDES
  echo "      - ASSET_HOST=http://$EXT_IP:3000" >> $COMPOSE_OVERRIDES
  echo "      - SETTINGS__DOMAIN=http://$EXT_IP:3000" \
       >> $COMPOSE_OVERRIDES
  echo "      - SETTINGS__STREAMING__HTTP_BASE=http://$EXT_IP:8880/avalon" \
       >> $COMPOSE_OVERRIDES
  echo "    ports:" >> $COMPOSE_OVERRIDES
  echo '      - "3000:80"' >> $COMPOSE_OVERRIDES
  echo '      - "8282:8282"' >> $COMPOSE_OVERRIDES
}

launch_services_www_docker() {
  cd $AVALON_DIR
  sudo su -c "(cd $AVALON_DIR; pwd; docker-compose up -d)" - $USER || exit
}

# I kind of gave up on this -- might persue it further in the future
launch_services_www_local() {
  cd $AVALON_DIR
  bundle install --path=vendor/bundle --with development test postgres aws \
         || exit
  # The su to $USER is to ensure that shell has user in docker group
  sudo su -c "(cd $AVALON_DIR; pwd; docker-compose up -d)" - $USER || exit
  sleep 120
  # Sometimes the container changes permissions of this dir
  sudo chown -R $USER:$USER $MASTERFILES
  # The path to masterfiles needs to match that in matterhorn container
  sudo ln -s $MASTERFILES /masterfiles

  bundle exec rake db:setup || exit
  bundle exec rake db:migrate || exit
  BACKGROUND=yes RAILS_ENV=development bundle exec rake resque:scheduler
  BACKGROUND=yes RAILS_ENV=development QUEUE=* bundle exec rake resque:work

  BIND_IP=`ifconfig | grep $BIND_NETWORK | sed 's/^.*addr://' | sed 's/ .*$//'`
  bundle exec rails s -b $BIND_IP -d
}

main || exit
