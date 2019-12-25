FreeDOS(98) kernel
==================

(日本語の説明は、下のほうに軽く書いておこう…)

This is an *experimental* port of the FreeDOS kernel for NEC PC-9801/9821 series.
Merge heavy works of predecessors (mostly not me) with current development kernel.

Base patches from:

* http://www.retropc.net/tori/freedos/  
kernel 2028 (2005/7/24)(bootloader, sys.com)  
kernel 2035a (2005/7/25) (kernel)
* fd98patch-20060906.zip from http://bauxite.sakura.ne.jp/wiki/mypad.cgi?p=DOS%2FFreeDOS%2FFreeDOS%2898%29%2Ftemp

FreeDOS development kernel:

* http://www.fdos.org/
* http://github.com/FDOS/kernel/
* http://github.com/PerditionC/fdkernel/


TODO
----

* Improve compatibilities  
(int 0xDC, internal memory layout, many FEPs support...)
* etc, etc...


補足説明
--------

最近の FreeDOS のカーネルソースに FreeDOS(98) の内容をとりあえず移植してみたものです（2016-01-25現在）。  
安定性に関してはお察しください。

ビルドには OpenWatcom, nasm, upx, GNU make（Windowsでビルドを行う際には mingw32 もしくは mingw-w64 の gcc についてくる mingw32-make もしくは mingw64-make）が必要です。OpenWatcom 以外のコンパイラには対応していません。  
（OpenWatcom のインストーラは 16bit ターゲット向けのコンパイラやライブラリをすべてインストールしてくれないので、インストール時にマニュアルですべてチェックする必要があるかもしれません）  
Linux 上でビルドする際には gcc も必要です。


