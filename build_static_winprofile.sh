#!/usr/bin/bash

CPU=`uname -m`
FFMPEG="ffmpeg-3.2.3-1"
MINIDLNA="minidlna-1.1.6-1"

# Partially borrowed from apt-cyg
function wget {
  if command wget -h &>/dev/null
  then
    command wget "$@"
  else
    warn wget is not installed, using lynx as fallback
    set "${*: -1}"
    lynx -source "$1" > "${1##*/}"
  fi
}

function find-workspace {
  # default working directory and mirror

  # work wherever setup worked last, if possible
  cache=$(awk '
  BEGIN {
    RS = "\n\\<"
    FS = "\n\t"
  }
  $1 == "last-cache" {
    print $2
  }
  ' /etc/setup/setup.rc)

  mirror=$(awk '
  /last-mirror/ {
    getline
    print $1
  }
  ' /etc/setup/setup.rc)
  mirrordir=$(sed '
  s / %2f g
  s : %3a g
  ' <<< "$mirror")

  mkdir -p "$cache/$mirrordir/$arch"
  cd "$cache/$mirrordir/$arch"
  if [ -e setup.ini ]
  then
    return 0
  else
    get-setup
    return 1
  fi
}

function get-setup {
  touch setup.ini
  mv setup.ini setup.ini-save
  wget -N $mirror/$arch/setup.bz2
  if [ -e setup.bz2 ]
  then
    bunzip2 setup.bz2
    mv setup setup.ini
    echo Updated setup.ini
  else
    echo Error updating setup.ini, reverting
    mv setup.ini-save setup.ini
  fi
}

function download-source {
  local pkg digest digactual
  pkg=$1
  # look for package and save desc file

  awk '$1 == pc' RS='\n\n@ ' FS='\n' pc=$pkg setup.ini > desc
  if [ ! -s desc ]
  then
    echo Unable to locate package $pkg
    exit 1
  fi

  # download and unpack the bz2 or xz file

  # pick the latest version, which comes first
  set -- $(awk '$1 == "source:"' desc)
  if (( ! $# ))
  then
    echo 'Could not find "source" in package description: obsolete package?'
    exit 1
  fi

  dn=$(dirname $2)
  bn=$(basename $2)

  # check the md5
  digest=$4
  case ${#digest} in
   32) hash=md5sum    ;;
  128) hash=sha512sum ;;
  esac
  mkdir -p "$cache/$mirrordir/$dn"
  cd "$cache/$mirrordir/$dn"
  if ! test -e $bn || ! $hash -c <<< "$digest $bn"
  then
    wget -O $bn $mirror/$dn/$bn
    $hash -c <<< "$digest $bn" || exit
  fi

  cd ~-
  mv desc "$cache/$mirrordir/$dn"
  echo $dn $bn > /tmp/dwn
}

function install-source {
  find-workspace
  local pkg dn bn sn
  pkg=$1
  download-source $pkg

  read dn bn </tmp/dwn
  echo Unpacking...

  cd "$cache/$mirrordir/$dn"
  sn=$(basename $bn | sed -E -e 's/-src\.tar\..+$//')

  if tar tf $bn | grep -q "\.src/"
  then
    tar -x -C /usr/src -f $bn
  else
    mkdir -p /usr/src/$sn.src
    tar -x -C /usr/src/$sn.src -f $bn
  fi
  echo Source package $pkg installed
  echo /usr/src/$sn.src > /tmp/dwn
}

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

readonly arch=${HOSTTYPE/i6/x}
cwd=$(pwd)

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
# Install prereqs
apt-cyg install gperf libiconv-devel libicu-devel libintl-devel \
                gettext-devel libreadline-devel tcl-devel openssl-devel \
		zlib-devel nasm yasm
# Install minidlna prereqs
export CYGCONF_ARGS="--enable-static"

if [ ! -f /usr/lib/libid3tag.a ]
then
  install-source libid3tag-devel
  read dir </tmp/dwn
  pushd $dir
    fn=$(basename $dir | sed -e 's/\.src$//')
    cygport $fn.cygport all
    for pkg in $(find $fn.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
    do
      local-install $pkg
    done
  popd
fi

if [ ! -f /usr/lib/libsqlite3.a ]
then
  install-source libsqlite3-devel
  read dir </tmp/dwn
  pushd $dir
    fn=$(basename $dir | sed -e 's/\.src$//')
    cp $fn.cygport $fn.cygport.orig
    sed -e 's/libsqlite3\*.dll.a/libsqlite3*.a/' $fn.cygport.orig > $fn.cygport
    cygport $fn.cygport prep compile install
    # Current packaging seems to be broken, manual hack to fix it
    install $fn.$CPU/src/*/spaceanal.tcl $fn.$CPU/inst/usr/bin/sqlite3_analyzer
    pushd $fn.$CPU/inst/usr/lib
      for d in $(find -type d -name "sqlite3.*")
      do
        nd=$(echo $d | sed -e 's/sqlite3.*$/sqlite3/')
        mv $d $nd
      done
    popd
    cygport $fn.cygport package
    rm $fn.cygport
    mv $fn.cygport.orig $fn.cygport
    for pkg in $(find $fn.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" \
                ! -iname "*-debuginfo*" ! -iname "*mingw*")
    do
      local-install $pkg
    done
  popd
fi

if [ ! -f /usr/lib/libjpeg.a ]
then
  install-source libjpeg-devel
  read dir </tmp/dwn
  pushd $dir
    fn=$(basename $dir | sed -e 's/\.src$//')
    sed -e 's/CYGCONF_ARGS="/CYGCONF_ARGS="\$CYGCONF_ARGS /' libjpeg-turbo.cygport > libjpeg-turbo.mod.cygport
    cygport libjpeg-turbo.mod.cygport all
    rm libjpeg-turbo.mod.cygport
    for pkg in $(find $fn.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
    do
      local-install $pkg
    done
  popd
fi

if [ ! -f /usr/lib/libexif.a ]
then
  install-source libexif-devel
  read dir </tmp/dwn
  pushd $dir
    fn=$(basename $dir | sed -e 's/\.src$//')
    sed -e 's/CYGCONF_ARGS="/CYGCONF_ARGS="\$CYGCONF_ARGS /' $fn.cygport > $fn.mod.cygport
    cygport $fn.mod.cygport prep compile install
    # Hack to fix packaging
    tar -x -C $fn.mod.$CPU/inst/usr/share/doc/libexif -f $fn.mod.$CPU/src/*/doc/libexif-api.html.tar.gz
    cygport $fn.mod.cygport package
    rm $fn.mod.cygport
    for pkg in $(find $fn.mod.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
    do
      local-install $pkg
    done
  popd
fi

if [ ! -f /usr/lib/libogg.a ]
then
  install-source libogg-devel
  read dir </tmp/dwn
  pushd $dir
    fn=$(basename $dir | sed -e 's/\.src$//')
    cygport libogg.cygport all
    for pkg in $(find $fn.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
    do
      local-install $pkg
    done
  popd
fi

if [ ! -f /usr/lib/libvorbis.a ]
then
  install-source libvorbis-devel
  read dir </tmp/dwn
  pushd $dir
    fn=$(basename $dir | sed -e 's/\.src$//')
    echo "01-autoreconf.patch" > series
    cygport libvorbis.cygport all
    rm series
    for pkg in $(find $fn.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
    do
      local-install $pkg
    done
  popd
fi

if [ ! -f /usr/lib/libFLAC.a ]
then
  install-source flac-devel
  read dir </tmp/dwn
  pushd $dir
    fn=$(basename $dir | sed -e 's/\.src$//')
    sed -e 's/CYGCONF_ARGS="/CFLAGS="-ggdb -O2 -pipe -Wimplicit-function-declaration -D_O_BINARY=O_BINARY"\nCYGCONF_ARGS="\$CYGCONF_ARGS /' flac.cygport > flac.mod.cygport
    echo "01-do_not_use__fileno.patch 02-no_win_utf8_io.patch 03-fix_O_BINARY.patch" > series
    cygport flac.mod.cygport all
    rm series
    rm flac.mod.cygport
    for pkg in $(find $fn.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
    do
      local-install $pkg
    done
  popd
fi

cd $cwd

# Build ffmpeg if needed
if [ ! -f /usr/lib/libavutil.a ]
then
  unzip $FFMPEG.src.zip -d /usr/src/$FFMPEG.src
  pushd /usr/src/$FFMPEG.src
    echo "Building $FFMPEG..."
    cygport ffmpeg_static.cygport fetch all
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
  cygport minidlna_static_winprofile.cygport fetch prep compile install package
  echo "Installing $MINIDLNA..."
  for pkg in $(find $MINIDLNA.$CPU/dist/ -iname "*.tar.xz" ! -iname "*-src.tar.xz" ! -iname "*-debuginfo*")
  do
    local-install $pkg
  done
popd
