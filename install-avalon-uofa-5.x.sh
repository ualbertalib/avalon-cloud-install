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

AVALON_REPO='https://github.com/ualbertalib/avalon.git'
AVALON_BRANCH='docker-on-compute-canada'

AVALON_DOCKER_REPO='https://github.com/ualbertalib/avalon-docker.git'
AVALON_DOCKER_BRANCH='ualberta_avalon_dev_environment'

SRC_DIR=$HOME/gitwork
AVALON_DIR=$SRC_DIR/avalon
AVALON_DOCKER_DIR=$SRC_DIR/avalon-docker

MASTERFILES=$AVALON_DIR/masterfiles

GIT_USER='Chris Want'
GIT_EMAIL='cjwant@gmail.com'
GIT_EDITOR=emacs

# BIND_NETWORK='192.168'

main() {
  setup_hostname || exit
  install_packages || exit
  install_docker || exit
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

install_sources() {
  git config --global user.email "$GIT_EMAIL"
  git config --global user.name "$GIT_USER"
  git config --global core.editor "$GIT_EDITOR"

  mkdir -p $SRC_DIR

  cd $SRC_DIR
  [ -d avalon ] || git clone $AVALON_REPO || exit
  cd $AVALON_DIR
  git checkout $AVALON_BRANCH || exit

  cd $SRC_DIR
  [ -d avalon-docker ] || git clone $AVALON_DOCKER_REPO || exit
  cd $AVALON_DOCKER_DIR
  git checkout $AVALON_DOCKER_BRANCH || exit
}

configure_sources() {
  cd $AVALON_DOCKER_DIR
  EXT_IP=`curl -4 icanhazip.com`

  DOTENV=".env"
  echo "APP_NAME=avalon" >> $DOTENV
  echo "BASE_URL=http://$EXT_IP/" >> $DOTENV
  echo "STREAM_RTMP_BASE=http://$EXT_IP:1935/avalon" >> $DOTENV
  echo "STREAM_HTTP_BASE=http://$EXT_IP:8880/avalon" >> $DOTENV
  echo "STREAMING_HOST=$EXT_IP" >> $DOTENV
  echo "AVALON_DB_PASSWORD=dontcare" >> $DOTENV
  echo "FEDORA_DB_PASSWORD=dontcare" >> $DOTENV
  echo "SECRET_KEY_BASE=dontcare" >> $DOTENV
  echo "AVALON_SRC=$AVALON_DIR" >> $DOTENV
  echo "APP_UID=1000" >> $DOTENV
  echo "APP_GID=1000" >> $DOTENV
  echo "AVALON_BRANCH=master" >> $DOTENV
  echo "EMAIL_COMMENTS=avalon-comments@example.edu" >> $DOTENV
  echo "EMAIL_NOTIFICATION=avalon-notifications@example.edu" >> $DOTENV
  echo "EMAIL_SUPPORT=avalon-support@example.edu" >> $DOTENV
  echo "SMTP_ADDRESS=smtp.example.edu" >> $DOTENV
  echo "SMTP_PORT=587" >> $DOTENV
}

launch_services_www_docker() {
  sudo su -c "(cd $AVALON_DOCKER_DIR; pwd; docker-compose up -d)" - $USER \
      || exit
}

main || exit
