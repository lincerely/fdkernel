FreeDOS DBCS kernel (for IBM PC and NEC PC-98 series)
=====================================================

http://bauxite.sakura.ne.jp/software/dos/freedos.htm#fdkernel  
https://github.com/lpproj/fdkernel  
(branch: nec98test)

This is a fork of [FreeDOS development kernel](https://github.com/PerditionC/fdkernel/), intended to handle correctly double-byte character set (DBCS) like Japanese:

* handle DBCS pathname on file manipulation (create, open, find, rename and so on)
* handle DBCS characters on input/output for character devices (not implemented yet)
* DBCS-awared NLS functions: upcase, downcase and collating 

All tasks are working-in-progress and *unstable (experimental)*.


FreeDOS(98) : FreeDOS kernel for NEC PC-9801/9821 series
--------------------------------------------------------

Now FreeDOS DBCS kernel also supports not only IBM PC (compatibles) but NEC PC-9801/9821 series (and compatibles made by EPSON). The portion was based on [tori's work (Another FreeDOS(98)](http://www.retropc.net/tori/freedos/), and [I (lpproj)](bauxite.sakura.ne.jp/software/dos/freedos.htm) add a little improvements:

* sync with latest fdkernel
* supports both FD (2DD/2HD/1.44M) and HD (SASI/SCSI)
* supports various sizes of sector (256 and 512 bytes for physical, up to 2048 bytes for logical)
* handle DBCS pathname
* improve compatibility with genuine (NEC) MS-DOS

Needless to say, this port is an *experimental*.


Build Prerequisites
-------------------

You can build FreeDOS DBCS kernel (ibmpc or nec98) on Windows (x86/x64) or Linux (i*86/amd64).

* OpenWatcom C/C++ (other compilers are not supported)
* [nasm](http://www.nasm.us/)
* [upx](http://upx.sourceforge.net/) : The official build is recommended ("open-source" edition has less performance for compression than the official) 
* GNU make (mingw32-make.exe, on Windows)

build step for FreeDOS for PC-9801/9821:

1. `cd nec98` (When you want to build for IBM PC, type `cd ibmpc`)
2. `copy config.m config.mak` (on Linux, `cp config.m config.mak`)
3. Edit `config.mak` for your configuration.
4. `mingw32-make clobber` (on Linux, `make clobber`)
5. `mingw32-make all` (on Linux, `make all`)

When you don't need DBCS featues, you should modify `platform.mak` and remove `-DDBCS` 

