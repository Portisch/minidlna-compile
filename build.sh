#!/usr/bin/bash

CPU=`uname -m`
FFMPEG="ffmpeg-3.2.3-1"
MINIDLNA="minidlna-cygwin-1"

# Partially borrowed from apt-cyg
function local-install {
  local pkg fn bn script
  echo $1
  fn=$1
  bn=$(basename $1)
  pkg=$(echo $bn | sed -E -e 's/-[0-9]+\.[0-9]+.*$//')

  if [ ! -f $fn ]
  then
    echo "File $fn doesn't exist"
    return 1
  fi

  echo Installing $pkg
  echo Unpacking...

  tar -x -C / -f $fn
  # update the package database
  tar tf $fn | gzip > /etc/setup/"$pkg".lst.gz

  awk '
  ins != 1 && pkg < $1 {
    print pkg, bz, 0
    ins = 1
  }
  1
  END {
    if (ins != 1) print pkg, bz, 0
  }
  ' pkg="$pkg" bz=$bn /etc/setup/installed.db > /tmp/awk.$$
  mv /etc/setup/installed.db /etc/setup/installed.db-save
  mv /tmp/awk.$$ /etc/setup/installed.db

  # run all postinstall scripts

  find /etc/postinstall -name '*.sh' | while read script
  do
    echo Running $script
    $script
    mv $script $script.done
  done
  echo Package $pkg installed
}

# Get apt-cyg
if [ ! -f /bin/apt-cyg ]
then
  lynx -source rawgit.com/transcode-open/apt-cyg/master/apt-cyg > apt-cyg
  install apt-cyg /bin
  rm apt-cyg
fi

# Install prereqs
apt-cyg install wget
apt-cyg install cygport
# Install ffmpeg prereqs
apt-cyg install yasm
# Install minidlna prereqs
apt-cyg install libid3tag-devel libsqlite3-devel libjpeg-devel libexif-devel libogg-devel \
libvorbis-devel flac-devel libiconv-devel libintl-devel gettext-devel

# Build ffmpeg if needed
if [ ! -f /usr/lib/libavutil.a ]
then
  unzip $FFMPEG.src.zip -d /usr/src/$FFMPEG.src
  pushd /usr/src/$FFMPEG.src
    echo "Building $FFMPEG..."
    cygport ffmpeg.cygport fetch all
    echo "Installing $FFMPEG..."
    for pkg in $(find $FFMPEG.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
    do
      local-install $pkg
    done
  popd
fi

# Build minidlna
unzip $MINIDLNA.src.zip -d /usr/src/$MINIDLNA.src
pushd /usr/src/$MINIDLNA.src
  echo "Building $MINIDLNA..."
  cygport minidlna.cygport fetch prep compile install package
  echo "Installing $MINIDLNA..."
  for pkg in $(find $MINIDLNA.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
  do
    local-install $pkg
  done
popd
