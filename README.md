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
