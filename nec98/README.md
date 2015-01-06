FreeDOS(98) kernel
==================

(日本語の説明は、下のほうに軽く書いておこう…)

This is an *experimental* port of the FreeDOS kernel for NEC PC-9801/9821 series.
Merge heavy works of predecessors (mostly not me) with current development kernel.

Base patches from:

* http://www.retropc.net/tori/freedos/
** kernel 2028 (2005/7/24)  (bootloader, sys.com)  
** kernel 2035a (2005/7/25) (kernel)
* from http://bauxite.sakura.ne.jp/wiki/mypad.cgi?p=DOS%2FFreeDOS%2898%29%2Ftemp
** fd98patch-20060906.zip

FreeDOS development kernel:

* http://www.fdos.org/
* http://github.com/PerditionC/fdkernel/


Build Prerequisites
-------------------

You can build freedos(98) kernel on Windows (x86/x64) or Linux (i*86/amd64).

* OpenWatcom C/C++ (other compilers are not supported)
* nasm (http://www.nasm.us/)
* upx (http://upx.sourceforge.net/)
* GNU make (mingw32-make.exe, on Windows)

build step:

1. cd nec98
2. copy config.m config.mak (on Linux, cp config.m config.mak)
3. Edit config.mak for your configuration.
4. mingw32-make clobber (on Linux, make clobber)
5. mingw32-make all (on Linux, make all)


TODO
----

* Support FDs
* Support 2nd (and more) HDs
* Support FAT32
* DBCS pathname
* Improve compatibilities (int 0xDC, internal memory layout,...)
* etc, etc...


補足説明
--------

最近の FreeDOS のカーネルソースに FreeDOS(98) の内容をとりあえず移植してみたものです（2015-01-06現在）。
安定性に関してはお察しください。

ビルドには OpenWatcom, nasm, upx, GNU make（Windowsでビルドを行う際には mingw32 もしくは mingw-w64 の gcc についてくる mingw32-make もしくは mingw64-make） が必要です。
OpenWatcom 以外のコンパイラには対応していません。
（OpenWatcom のインストーラは 16bit ターゲット向けのコンパイラやライブラリをすべてインストールしてくれないので、インストール時にマニュアルですべてチェックする必要があるかもしれません）
Linux 上でビルドする際には gcc も必要です。

