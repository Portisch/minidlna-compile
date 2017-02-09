# minidlna-compile

Based on the scripts of [hiero & nymous](https://sourceforge.net/p/minidlna/patches/33/).

Source based on minidlna at [sourceforge 2016-09-29 01:44:58](https://sourceforge.net/p/minidlna/git/ci/8a996b4b624ef45538a5de10730b8e94c55e7768/tree) (v1.1.6).

## Prerequisites
[Cygwin](https://www.cygwin.com/)

[Git for Windows](https://git-scm.com/)

### HowTo compile
1. Install Cygwin to C:\cygwin
  1. Install package "lynx"
2. Install Git for Windows
3. Open a Git Bash in the folder C:\cygwin\usr\src
  1. Clone **minidlna-compile**: "git clone https://github.com/Portisch/minidlna-compile" 
4. Open Cygwin-Terminal
  1. Enter "cd /usr/src/minidlna-compile" to navigate to the cloned repository
    1. Enter "./build.sh" or
    2. Enter "./build_static.sh" or
    3. Enter "./build_static_winprofile.sh"
    
#### Last test with

ffmpeg-3.2.3-1
flac-1.3.2-1
libexif-0.6.21-1
libid3tag-0.15.1b-10
libjpeg-turbo-1.5.0-1
libogg-1.3.1-1
libvorbis-1.3.5-1
sqlite3-3.16.2-1

cygport 0.23.1
