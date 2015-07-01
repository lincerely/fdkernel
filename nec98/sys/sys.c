/***************************************************************

                                    sys.c
                                    DOS-C

                            sys utility for DOS-C

                             Copyright (c) 1991
                             Pasquale J. Villani
                             All Rights Reserved

 This file is part of DOS-C.

 DOS-C is free software; you can redistribute it and/or modify it under the
 terms of the GNU General Public License as published by the Free Software
 Foundation; either version 2, or (at your option) any later version.

 DOS-C is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 details.

 You should have received a copy of the GNU General Public License along with
 DOS-C; see the file COPYING.  If not, write to the Free Software Foundation,
 675 Mass Ave, Cambridge, MA 02139, USA.

***************************************************************/

/* 
    TE thinks, that the boot info storage should be done by FORMAT, noone else

    unfortunately, that doesn't work ???
*/
#define STORE_BOOT_INFO

#define DEBUG
/* #define DDEBUG */

#define SYS_VERSION "v2.5"
#define SYS98_VERSION "20150624"

#include <stdlib.h>
#include <dos.h>
#include <ctype.h>
#include <fcntl.h>
#include <sys/stat.h>
#ifdef __TURBOC__
#include <mem.h>
#else
#include <memory.h>
#endif
#include <string.h>
#ifdef __TURBOC__
#include <dir.h>
#endif
#define SYS_MAXPATH   260
#include "portab.h"
#if !defined(__WATCOMC__)
extern WORD CDECL printf(CONST BYTE * fmt, ...);
extern WORD CDECL sprintf(BYTE * buff, CONST BYTE * fmt, ...);
#endif

#if defined(NEC98) || defined(FOR_NEC98)
/* todo... support fat32 boot (really?) */
#undef WITHFAT32
#endif

#include "b_fat12.h"
#include "b_fat12f.h"
#include "b_fat16.h"
#ifdef WITHFAT32
#include "b_fat32.h"
#endif

#ifndef __WATCOMC__
#include <io.h>
#else
#include <stdio.h>
int unlink(const char *pathname);
/* some non-conforming functions to make the executable smaller */
int open(const char *pathname, int flags, ...)
{
  int handle;
  int result = (flags & O_CREAT ?
                _dos_creat(pathname, _A_NORMAL, &handle) :
                _dos_open(pathname, flags & (O_RDONLY | O_WRONLY | O_RDWR),
                          &handle));

  return (result == 0 ? handle : -1);
}

int read(int fd, void *buf, unsigned count)
{
  unsigned bytes;
  int result = _dos_read(fd, buf, count, &bytes);

  return (result == 0 ? bytes : -1);
}

int write(int fd, const void *buf, unsigned count)
{
  unsigned bytes;
  int result = _dos_write(fd, buf, count, &bytes);

  return (result == 0 ? bytes : -1);
}

#define close _dos_close

int stat(const char *file_name, struct stat *buf)
{
  struct find_t find_tbuf;
  UNREFERENCED_PARAMETER(buf);
  
  return _dos_findfirst(file_name, _A_NORMAL | _A_HIDDEN | _A_SYSTEM, &find_tbuf);
}
#endif

BYTE pgm[] = "SYS";

void put_boot(COUNT, BYTE *, BOOL);
BOOL check_space(COUNT, BYTE *);
BOOL copy(COUNT drive, BYTE * srcPath, BYTE * rootPath, BYTE * file);
COUNT DiskRead(WORD, WORD, WORD, WORD, WORD, BYTE FAR *);
COUNT DiskWrite(WORD, WORD, WORD, WORD, WORD, BYTE FAR *);

#define MAX_SEC_SIZE    (512 * 8)
#define COPY_SIZE	0x7e00

#ifdef _MSC_VER
#pragma pack(1)
#endif

struct bootsectortype {
  UBYTE bsJump[3];              /* nec98: eb 45 90 (DOS 5, DOS 6.20) */
  char OemName[8];
  UWORD bsBytesPerSec;
  UBYTE bsSecPerClust;
  UWORD bsResSectors;
  UBYTE bsFATs;
  UWORD bsRootDirEnts;
  UWORD bsSectors;
  UBYTE bsMedia;
  UWORD bsFATsecs;
  UWORD bsSecPerTrack;
  UWORD bsHeads;
  ULONG bsHiddenSecs;
  ULONG bsHugeSectors;
  UBYTE bsDriveNumber;
  UBYTE bsReserved1;
  UBYTE bsBootSignature;
  ULONG bsVolumeID;
  char bsVolumeLabel[11];
  char bsFileSysType[8];
#if 1
  ULONG sysPartStart;           /* nec98: first phys sector of the partition (same as bsHidden on DOS 5+) */
  UWORD sysDataOffset;          /* nec98: offset of IO.SYS sector (first data sector) */
  UWORD sysPhysicalBPS;         /* nec98: bytes/sector (Physical) */
  UBYTE unknown[1];             /* nec98: zero? */
  ULONG sysRootDirStart;        /* fd98: first root directory sector (logical sector, started from the partition) */
  UWORD sysRootDirSecs;         /* fd98: count of logical sectors root dir uses */
  ULONG sysFatStart;            /* fd98: first FAT sector (logical sector, started from the partition) */
  ULONG sysDataStart;           /* fd98: first data sector (logical sector, started from the partition) */
#else
  char unused[2];
  UWORD sysRootDirSecs;         /* of sectors root dir uses */
  ULONG sysFatStart;            /* first FAT sector */
  ULONG sysRootDirStart;        /* first root directory sector */
  ULONG sysDataStart;           /* first data sector */
  UWORD sysPhysicalBPS;         /* bytes/sector (Physical) */
#endif
};

struct nec3bootsectortype {     /* DOS 3.x HDD PBR (formatted with NEC DOS 3.x) */
  UBYTE bsJump[3];              /* nec98 DOS3.3 : 0xeb, 0x1f, 0x90 */
  char OemName[8];              /* nec98 DOS3.3 : all zero? */
  UWORD bsBytesPerSec;
  UBYTE bsSecPerClust;
  UWORD bsResSectors;
  UBYTE bsFATs;
  UWORD bsRootDirEnts;
  UWORD bsSectors;
  UBYTE bsMedia;
  UWORD bsFATsecs;
  ULONG sysPartStart;           /* nec98 DOS3.3 : first phys sector of the partition (same as bsHidden on DOS 5+) */
  UWORD sysDataOffset;          /* nec98 DOS3.3 : offset of IO.SYS sector (first data sector) */
  UWORD sysPhysicalBPS;         /* nec98 DOS3.3 : bytes/sector (Physical) */
  UBYTE unknown[1];             /* nec98 DOS3.3: zero? */
};

struct bootsectortype32 {
  UBYTE bsJump[3];
  char OemName[8];
  UWORD bsBytesPerSec;
  UBYTE bsSecPerClust;
  UWORD bsResSectors;
  UBYTE bsFATs;
  UWORD bsRootDirEnts;
  UWORD bsSectors;
  UBYTE bsMedia;
  UWORD bsFATsecs;
  UWORD bsSecPerTrack;
  UWORD bsHeads;
  ULONG bsHiddenSecs;
  ULONG bsHugeSectors;
  ULONG bsBigFatSize;
  UBYTE bsFlags;
  UBYTE bsMajorVersion;
  UWORD bsMinorVersion;
  ULONG bsRootCluster;
  UWORD bsFSInfoSector;
  UWORD bsBackupBoot;
  ULONG bsReserved2[3];
  UBYTE bsDriveNumber;
  UBYTE bsReserved3;
  UBYTE bsExtendedSignature;
  ULONG bsSerialNumber;
  char bsVolumeLabel[11];
  char bsFileSystemID[8];
  ULONG sysFatStart;
  ULONG sysDataStart;
  UWORD sysFatSecMask;
  UWORD sysFatSecShift;
};

UBYTE newboot[MAX_SEC_SIZE], oldboot[MAX_SEC_SIZE];

#define SBOFFSET        11
#define SBSIZE          (sizeof(struct bootsectortype) - SBOFFSET)
#define SBSIZE32        (sizeof(struct bootsectortype32) - SBOFFSET)

#if 1
/* nec98 todo: verify bootsectortype */
#else
/* essentially - verify alignment on byte boundaries at compile time  */
struct VerifyBootSectorSize {
  char failure1[sizeof(struct bootsectortype) == 80 ? 1 : -1];
  char failure2[sizeof(struct bootsectortype) == 80 ? 1 : 0];
};
#endif

int FDKrnConfigMain(int argc, char **argv);

int main(int argc, char **argv)
{
  COUNT drive;                  /* destination drive */
  COUNT drivearg = 0;           /* drive argument position */
  BYTE *bsFile = NULL;          /* user specified destination boot sector */
  unsigned srcDrive;            /* source drive */
  BYTE srcPath[SYS_MAXPATH];    /* user specified source drive and/or path */
  BYTE rootPath[4];             /* alternate source path to try if not '\0' */
  WORD slen;

  printf("FreeDOS(98) System Installer " SYS_VERSION "-" SYS98_VERSION "\n");

  if (argc > 1 && memicmp(argv[1], "CONFIG", 6) == 0)
  {
#if 0
    exit(FDKrnConfigMain(argc, argv));
#else
    printf("CONFIG is not supported.\n");
    exit(1);
#endif
  }

  srcPath[0] = '\0';
  if (argc > 1 && argv[1][1] == ':' && argv[1][2] == '\0')
    drivearg = 1;

  if (argc > 2 && argv[2][1] == ':' && argv[2][2] == '\0')
  {
    drivearg = 2;
    strncpy(srcPath, argv[1], SYS_MAXPATH - 12);
    /* leave room for COMMAND.COM\0 */
    srcPath[SYS_MAXPATH - 13] = '\0';
    /* make sure srcPath + "file" is a valid path */
    slen = strlen(srcPath);
    if ((srcPath[slen - 1] != ':') &&
        ((srcPath[slen - 1] != '\\') || (srcPath[slen - 1] != '/')))
    {
      srcPath[slen] = '\\';
      slen++;
      srcPath[slen] = '\0';
    }
  }

  if (drivearg == 0)
  {
    printf("Usage: %s [source] drive: [bootsect [BOTH]]\n", pgm);
    printf
        ("  source   = A:,B:,C:\\KERNEL\\BIN\\,etc., or current directory if not given\n");
    printf("  drive    = A,B,etc.\n");
    printf
        ("  bootsect = name of boot sector file image for drive:\n");
    printf("             to write to instead of real boot sector\n");
    printf
        ("  BOTH     : write to both the real boot sector and the image file\n");
    printf("%s CONFIG /help\n", pgm);
    exit(1);
  }
  drive = toupper(argv[drivearg][0]) - 'A';

  if (drive < 0 || drive >= 26)
  {
    printf("%s: drive %c must be A:..Z:\n", pgm,
           *argv[(argc == 3 ? 2 : 1)]);
    exit(1);
  }

  /* Get source drive */
  if ((strlen(srcPath) > 1) && (srcPath[1] == ':'))     /* src specifies drive */
    srcDrive = toupper(*srcPath) - 'A';
  else                          /* src doesn't specify drive, so assume current drive */
  {
#ifdef __TURBOC__
    srcDrive = (unsigned) getdisk();
#else
    _dos_getdrive(&srcDrive);
    srcDrive--;
#endif
  }

  /* Don't try root if src==dst drive or source path given */
  if ((drive == srcDrive)
      || (*srcPath
          && ((srcPath[1] != ':') || ((srcPath[1] == ':') && srcPath[2]))))
    *rootPath = '\0';
  else
    sprintf(rootPath, "%c:\\", 'A' + srcDrive);

  if (!check_space(drive, oldboot))
  {
    printf("%s: Not enough space to transfer system files\n", pgm);
    exit(1);
  }

  printf("\nCopying KERNEL.SYS...\n");
  if (!copy(drive, srcPath, rootPath, "kernel.sys"))
  {
    printf("\n%s: cannot copy \"KERNEL.SYS\"\n", pgm);
    exit(1);
  }

  if (argc > drivearg + 1)
    bsFile = argv[drivearg + 1];

  printf("\nWriting boot sector...\n");
  put_boot(drive, bsFile,
           (argc > drivearg + 2)
           && memicmp(argv[drivearg + 2], "BOTH", 4) == 0);

  printf("\nCopying COMMAND.COM...\n");
  if (!copy(drive, srcPath, rootPath, "COMMAND.COM"))
  {
    char *comspec = getenv("COMSPEC");
    if (comspec != NULL)
    {
      printf("%s: Trying \"%s\"\n", pgm, comspec);
      if (!copy(drive, comspec, NULL, "COMMAND.COM"))
        comspec = NULL;
    }
    if (comspec == NULL)
    {
      printf("\n%s: cannot copy \"COMMAND.COM\"\n", pgm);      
      exit(1);
    }
  }

  printf("\nSystem transferred.\n");
  return 0;
}

#ifdef DDEBUG
VOID dump_sector(unsigned char far * sec)
{
  COUNT x, y;
  char c;

  for (x = 0; x < 32; x++)
  {
    printf("%03X  ", x * 16);
    for (y = 0; y < 16; y++)
    {
      printf("%02X ", sec[x * 16 + y]);
    }
    for (y = 0; y < 16; y++)
    {
      c = oldboot[x * 16 + y];
      if (isprint(c))
        printf("%c", c);
      else
        printf(".");
    }
    printf("\n");
  }

  printf("\n");
}

#endif

/*
	get physical bytes per sector
*/

static UBYTE drive_to_daua(COUNT drive)
{
  UBYTE daua;
  if (drive < 0 || drive > 26)
    return 0;
  if (drive < 16)
    daua = *(UBYTE FAR *)(0x0060006cUL + drive);
  else
    daua = *(UBYTE FAR *)(0x00602c86UL + drive * 2 + 1);
  return daua;
}

static UBYTE is_fdd(COUNT drive, UBYTE daua)
{
  UBYTE da;
  
  if (drive >= 27 && daua == 0xff) return 0;
  if (daua == 0xff) {
    daua = drive_to_daua(drive);
  }
  da = daua >> 4;
  if (! (da == 1 || da == 3 || da == 5 || da == 7 || da == 9 || da == 0xf) )
    da = 0;
  
  return da;
}

static UWORD get_phybps(COUNT drive)
{
	union REGS regs;
	UBYTE daua;

#if 0
	struct SREGS sregs;
	UBYTE buf[0x60];

	regs.h.cl	= 0x13;
	sregs.ds	= FP_SEG(buf);
	regs.x.dx	= FP_OFF(buf);
	int86x(0xdc, &regs, &regs, &sregs);
	daua = buf[0x1a + drive * 2 + 1];
#else
	daua = *(UBYTE far *)(0x00602c86UL + drive * 2 + 1);
#endif

	regs.h.ah = 0x84;	/* sense */
	regs.h.al = daua;
	regs.x.bx = 0;
	int86(0x1b, &regs, &regs);
	if (regs.x.cflag || regs.x.bx == 0) {
		regs.x.bx = is_fdd(drive, daua) ? 0 : 256;
	}
	return regs.x.bx;
}

static int rewrite_bpb_geo(COUNT drive, struct bootsectortype *bs)
{
  union REGS regs;
  UBYTE daua;
  daua = drive_to_daua(drive);
  if (!daua)
    return 0xff;
  if (is_fdd(drive, daua))
  {
    *(UWORD *)&(bs->bsDriveNumber) = 0;
  }
  else
  {
    *(UWORD *)&(bs->bsDriveNumber) = daua;
    regs.h.ah = 0x84;
    regs.h.al = daua;
    regs.x.bx = 0;
    int86(0x1b, &regs, &regs);
    if (!regs.x.cflag && regs.x.bx)
    {
      bs->bsHeads = regs.h.dh;
      bs->bsSecPerTrack = regs.h.dl;
      bs->sysPhysicalBPS = regs.x.bx;
    }
    else
    {
      /* very old scsi ... not supported (yet) */
#if 1
      printf("Can't get information of HD geometry (drive %c)\n", 'A' + drive);
      exit(1);
#else
      return 0xff;
#endif
    }
  }
  return 0;
}

/*
    TC absRead not functional on MSDOS 6.2, large disks
    MSDOS requires int25, CX=ffff for drives > 32MB
*/

#ifdef __WATCOMC__
unsigned int2526readwrite(int DosDrive, void *diskReadPacket, unsigned intno, unsigned sector, unsigned count);
#pragma aux int2526readwrite =  \
      "push bp"           \
      "cmp si, 0x26"      \
      "je int26"          \
      "int 0x25"          \
      "jmp short cfltest" \
      "int26:"            \
      "int 0x26"          \
      "cfltest:"          \
      "pop ax"            \
      "sbb ax, ax"        \
      "pop bp"            \
      parm [ax] [bx] [si] [dx] [cx] \
      modify [ax bx cx dx si di es]      \
      value [ax];

unsigned fat32readwrite(int DosDrive, void *diskReadPacket, unsigned intno);
#pragma aux fat32readwrite =  \
      "mov ax, 0x7305"    \
      "mov cx, 0xffff"    \
      "inc dx"            \
      "sub si, 0x25"      \
      "int 0x21"          \
      "mov ax, 0"         \
      "adc ax, ax"        \
      parm [dx] [bx] [si] \
      modify [cx dx si]   \
      value [ax];

void reset_drive(int DosDrive);
#pragma aux reset_drive = \
      "push ds" \
      "inc dx" \
      "mov ah, 0xd" \ 
      "int 0x21" \
      "mov ah,0x32" \
      "int 0x21" \
      "pop ds" \
      parm [dx] \
      modify [ax bx];
#else
int2526readwrite(int DosDrive, void *diskReadPacket, unsigned intno, unsigned sector, unsigned count)
{
  union REGS regs;

  regs.h.al = (BYTE) DosDrive;
  regs.x.bx = FP_OFF(diskReadPacket);
  regs.x.cx = count;
  regs.x.dx = sector;

  int86x(intno, &regs, &regs);

  return regs.x.cflag;
}


fat32readwrite(int DosDrive, void *diskReadPacket, unsigned intno)
{
  union REGS regs;

  regs.x.ax = 0x7305;
  regs.h.dl = DosDrive + 1;
  regs.x.bx = (short)diskReadPacket;
  regs.x.cx = 0xffff;
  regs.x.si = intno - 0x25;
  int86(0x21, &regs, &regs);
  
  return regs.x.cflag;
}

void reset_drive(int DosDrive)
{
  union REGS regs;

  regs.h.ah = 0xd;
  int86(0x21, &regs, &regs);
  regs.h.ah = 0x32;
  regs.h.dl = DosDrive + 1;
  int86(0x21, &regs, &regs);
}

#endif

unsigned GetDosVersion(void)
{
  union REGS regs;
  unsigned version;
  
  regs.x.bx = 0xffff;
  regs.x.ax = 0x3306;
  int86(0x21, &regs, &regs);
  version = ((unsigned)(regs.h.bl) << 8) + regs.h.bh;
  if (regs.h.bl == 20)
    version = 0x0500; /* OS/2 v2+ -> almost DOS 5.0 */
  if (regs.h.al == 0xff || regs.x.bx == 0xffff)
  {
    regs.h.ah = 0x30;
    int86(0x21, &regs, &regs);
    version = ((unsigned)(regs.h.al) << 8) + regs.h.ah;
    if (regs.h.al == 10)
      version = 0x030a; /* OS/2 1.x -> almost DOS 3.1 */
  }
  
  return version;
}

int MyAbsReadWrite(int DosDrive, int count, ULONG sector, void *buffer,
                   unsigned intno)
{
  struct {
    unsigned long sectorNumber;
    unsigned short count;
    void far *address;
  } diskReadPacket;

  diskReadPacket.sectorNumber = sector;
  diskReadPacket.count = count;
  diskReadPacket.address = buffer;

  if (intno != 0x25 && intno != 0x26)
    return 0xff;

  if (GetDosVersion() < 0x031f) /* DOS 3.1, 3.30 */
  {
    if (sector >= 0xffffUL)
      return 0xff;
    return int2526readwrite(DosDrive, buffer, intno, (unsigned)sector, count);
  }

  if (int2526readwrite(DosDrive, &diskReadPacket, intno, 0, 0xffffU))
  {
#ifdef WITHFAT32
    return fat32readwrite(DosDrive, &diskReadPacket, intno);
#else
    return 0xff;
#endif
  }
  return 0;
}

#ifdef __WATCOMC__

unsigned getdrivespace(COUNT drive, unsigned *total_clusters);
#pragma aux getdrivespace =  \
      "mov ah, 0x36"      \
      "inc dx"            \
      "int 0x21"          \
      "mov [si], dx"      \
      parm [dx] [si]      \
      modify [bx cx dx]   \
      value [ax];

unsigned getextdrivespace(void *drivename, void *buf, unsigned buf_size);
#pragma aux getextdrivespace =  \
      "mov ax, 0x7303"    \
      "push ds"           \
      "pop es"            \
      "stc"		  \
      "int 0x21"          \
      "mov ax, 0"         \
      "adc ax, ax"        \
      parm [dx] [di] [cx] \
      modify [es]         \
      value [ax];

#else

unsigned getdrivespace(COUNT drive, unsigned *total_clusters)
{
  union REGS regs;

  regs.h.ah = 0x36;             /* get drive free space */
  regs.h.dl = drive + 1;        /* 1 = 'A',... */
  int86(0x21, &regs, &regs);
  *total_clusters = regs.x.dx;
  return regs.x.ax;
}

unsigned getextdrivespace(void *drivename, void *buf, unsigned buf_size)
{
  union REGS regs;
  struct SREGS sregs;

  regs.x.ax = 0x7303;         /* get extended drive free space */

  sregs.es = FP_SEG(buf);
  regs.x.di = FP_OFF(buf);
  sregs.ds = FP_SEG(drivename);
  regs.x.dx = FP_OFF(drivename);

  regs.x.cx = buf_size;

  int86x(0x21, &regs, &regs, &sregs);
  return regs.x.ax == 0x7300 || regs.x.cflag;
}

#endif

VOID put_boot(COUNT drive, BYTE * bsFile, BOOL both)
{
  ULONG temp;
  struct bootsectortype *bs;
#ifdef WITHFAT32
  struct bootsectortype32 *bs32;
#endif
  int fs;
  char drivename[] = "A:\\";
  static unsigned char x[0x40]; /* we make this static to be 0 by default -
				   this avoids FAT misdetections */
  unsigned total_clusters;

  memset(newboot, 0, sizeof(newboot));
  memset(oldboot, 0, sizeof(oldboot));

#ifdef DEBUG
  printf("Reading old bootsector from drive %c:\n", drive + 'A');
#endif

  reset_drive(drive);
  if (MyAbsReadWrite(drive, 1, 0, oldboot, 0x25) != 0)
  {
    printf("can't read old boot sector for drive %c:\n", drive + 'A');
    exit(1);
  }

#ifdef DDEBUG
  printf("Old Boot Sector:\n");
  dump_sector(oldboot);
#endif

  bs = (struct bootsectortype *)&oldboot;
  if (bs->bsBytesPerSec * bs->bsResSectors < 512)
  {
    printf("The boot sector is too small (less than 512bytes)\n");
    exit(1);
  }
  if (bs->bsBootSignature != 0x29)
  {
    /* non extended BPB */
    struct nec3bootsectortype *bsnec3 = (struct nec3bootsectortype *)&oldboot;
    if (memcmp(bsnec3->bsJump, "\xeb" "\x1f" "\x90", 3) == 0 && bsnec3->bsMedia == 0xf8)
    {
      /* if the PBR is NEC DOS 3.3 one, fetch the beginning LBA */
      bs->sysPartStart = bsnec3->sysPartStart;
      bs->bsHiddenSecs = bs->sysPartStart;
#ifdef DEBUG
      printf("The boot sector has non-extended BPB (maybe NEC DOS 3.x HD)\n");
#endif
    }
    else
    {
      if (memcmp(bsnec3->OemName, "FreeDOS", 7) == 0) /* check retouch by FreeDOS(98) */
      {
#ifdef DEBUG
        printf("The boot sector has non-extended BPB (maybe FreeDOS98)\n");
#endif
      }
      else
      {
        /* todo: check FDs, and EPSON DOS 3.x HD... */
        printf("unsupported partition!\n");
        exit(1);
      }
    }
#if 0
    if (bs->bsHeads == 0)
      bs->bsHeads = 1;
    bs->bsHiddenSecs &= 0xffffU;
#endif
    bs->bsHugeSectors = 0;
  }
  if ((bs->bsFileSysType[4] == '6') && (bs->bsBootSignature == 0x29))
  {
    fs = 16;
  }
  else
  {
    fs = 12;
  }

/*
    the above code is not save enough for me (TE), so we change the
    FS detection method to GetFreeDiskSpace().
    this should work, as the disk was writeable, so GetFreeDiskSpace should work.
*/

  if (getdrivespace(drive, &total_clusters) == 0xffff)
  {
    printf("can't get free disk space for %c:\n", drive + 'A');
    exit(1);
  }

  if (total_clusters <= 0xff6)
  {
    if (fs != 12)
#if defined(NEC98)
      printf("warning : new detection overrides old detection\n");
#else
      printf("warning : new detection overrides old detection\a\n");
#endif
    fs = 12;
  }
  else
  {

    if (fs != 16)
#if defined(NEC98)
      printf("warning : new detection overrides old detection\n");
#else
      printf("warning : new detection overrides old detection\a\n");
#endif
    fs = 16;

    /* fs = 16/32.
       we don't want to crash a FAT32 drive
     */

    drivename[0] = 'A' + drive;
    if (getextdrivespace(drivename, x, sizeof(x)))
    /* error --> no Win98 --> no FAT32 */
    {
      printf("get extended drive space not supported --> no FAT32\n");
    }
    else
    {
      if (*(unsigned long *)(x + 0x10)  /* total number of clusters */
          > (unsigned)65526l)
      {
        fs = 32;
      }
    }
  }

  if (fs == 16)
  {
    memcpy(newboot, b_fat16, sizeof(b_fat16)); /* copy FAT16 boot sector */
    printf("FAT type: FAT16\n");
    printf("BOOT type: LBA(HDD)\n");
  }
  else if (fs == 12)
  {
    if (is_fdd(drive, 0xff)) {
      memcpy(newboot, b_fat12f, sizeof(b_fat12f)); /* FAT12(FD) boot sector */
      printf("FAT type: FAT12\n");
      printf("BOOT type: CHS(FDD)\n");
    }
    else {
      memcpy(newboot, b_fat12, sizeof(b_fat12)); /* copy FAT12 boot sector */
      printf("FAT type: FAT12\n");
      printf("BOOT type: LBA(HDD)\n");
    }
  }
  else
  {
    printf("FAT type: FAT32\n");
#ifdef WITHFAT32
    memcpy(newboot, b_fat32, sizeof(b_fat32)); /* copy FAT32 boot sector */
#else
    printf("SYS hasn't been compiled with FAT32 support.");
    printf("Consider using -DWITHFAT32 option.\n");
    exit(1);
#endif
  }

  /* Copy disk parameter from old sector to new sector */
#ifdef WITHFAT32
  if (fs == 32)
    memcpy(&newboot[SBOFFSET], &oldboot[SBOFFSET], SBSIZE32);
  else
#endif
    memcpy(&newboot[SBOFFSET], &oldboot[SBOFFSET], SBSIZE);

  bs = (struct bootsectortype *)&newboot;

#if defined(NEC98)
  rewrite_bpb_geo(drive, bs);
  if (bs->bsBootSignature != 0x29 && fs != 32)
  {
    /* write dummy for a proof */
    bs->bsHugeSectors = 0;
    bs->bsVolumeID = 0;
    memcpy(bs->bsVolumeLabel, "NO NAME    ", sizeof bs->bsVolumeLabel);
  }
#endif
/*
  memcpy(bs->OemName, "FreeDOS ", 8);
*/

#ifdef WITHFAT32
  if (fs == 32)
  {
    bs32 = (struct bootsectortype32 *)&newboot;

    temp = bs32->bsHiddenSecs + bs32->bsResSectors;
    bs32->sysFatStart = temp;

    bs32->sysDataStart = temp + bs32->bsBigFatSize * bs32->bsFATs;
    bs32->sysFatSecMask = bs32->bsBytesPerSec / 4 - 1;

    temp = bs32->sysFatSecMask + 1;
    for (bs32->sysFatSecShift = 0; temp != 1;
         bs32->sysFatSecShift++, temp >>= 1) ;
    /* put 0 for A: or B: (force booting from A:), otherwise use DL */
/*
    bs32->bsDriveNumber = drive < 2 ? 0 : 0xff;
*/
  }
#ifdef DEBUG
  if (fs == 32)
  {
    printf("FAT starts at sector %lx = (%lx + %x)\n", bs32->sysFatStart,
           bs32->bsHiddenSecs, bs32->bsResSectors);
    printf("DATA starts at sector %lx\n", bs32->sysDataStart);
  }
#endif
  else
#endif
  {
#ifdef STORE_BOOT_INFO
# if 0
    /* TE thinks : never, see above */
    /* temporary HACK for the load segment (0x0060): it is in unused */
    /* only needed for older kernels */
    *((UWORD *) (bs->unused)) =
        *((UWORD *) (((struct bootsectortype *)&b_fat16)->unused));
    /* end of HACK */
# endif
    /* root directory sectors */

# if 1
    bs->sysPhysicalBPS = get_phybps(drive);
    if (bs->sysPhysicalBPS == 0) bs->sysPhysicalBPS = bs->bsBytesPerSec;
    
    temp = 0; /* bs->bsHiddenSecs; */
    temp += bs->bsResSectors;
    bs->sysFatStart = temp;
    temp += (ULONG)bs->bsFATsecs * bs->bsFATs;
    bs->sysRootDirStart = temp;
    bs->sysRootDirSecs = (UWORD)((ULONG)bs->bsRootDirEnts * 32L / bs->bsBytesPerSec);
    temp += bs->sysRootDirSecs;
    bs->sysDataStart = temp;
    
# else
    bs->sysRootDirSecs = (UWORD)((ULONG)bs->bsRootDirEnts * 32L / bs->bsBytesPerSec);

    /* sector FAT starts on */
    temp = bs->bsResSectors;
    bs->sysFatStart = temp;

    /* sector root directory starts on */
    temp += (ULONG)bs->bsFATsecs * bs->bsFATs;
    bs->sysRootDirStart = temp;

    /* sector data starts on */
    temp += bs->sysRootDirSecs;
    bs->sysDataStart = temp;

	/* physical bytes per sector */
    bs->sysPhysicalBPS = get_phybps(drive);
    if (bs->sysPhysicalBPS == 0) bs->sysPhysicalBPS = bs->bsBytesPerSec;

# endif
    /* put 0 for A: or B: (force booting from A:), otherwise use DL */
/*
    bs->bsDriveNumber = drive < 2 ? 0 : 0xff;
*/
  }

#ifdef DEBUG
  {
  UWORD s_scale = bs->bsBytesPerSec / bs->sysPhysicalBPS;
  printf("Root dir entries = %u\n", bs->bsRootDirEnts);
  printf("Root dir sectors = %u\n", bs->sysRootDirSecs);

  printf("FAT starts at sector            = %lu (%lu)\n", bs->sysFatStart, bs->bsHiddenSecs + bs->sysFatStart * s_scale);
  printf("Root directory starts at sector = %lu (%lu)\n", bs->sysRootDirStart, bs->bsHiddenSecs + bs->sysRootDirStart * s_scale);
  printf("DATA starts at sector           = %lu (%lu)\n", bs->sysDataStart, bs->bsHiddenSecs + bs->sysDataStart * s_scale);

  printf("Logical bytes per sector  = %u\n", bs->bsBytesPerSec);
  printf("Physical bytes per sector = %u\n", bs->sysPhysicalBPS);
  
  #if 1
  printf("Sectors per track         = %u\n", bs->bsSecPerTrack);
  printf("Heads                     = %u\n", bs->bsHeads);
  printf("Hidden sectors            = %lu\n", bs->bsHiddenSecs);
  #endif
  }
#endif
#endif

#ifdef DDEBUG
  printf("\nNew Boot Sector:\n");
  dump_sector(newboot);
#endif

  if ((bsFile == NULL) || both)
  {

#ifdef DEBUG
    printf("writing new bootsector to drive %c:\n", drive + 'A');
#endif

#if defined(TEST_SYS)
    printf("test mode ... not write the boot sector.\n");
#else
    if (MyAbsReadWrite(drive, 1, 0, newboot, 0x26) != 0)
    {
      printf("Can't write new boot sector to drive %c:\n", drive + 'A');
      exit(1);
    }
#endif
  }

  if (bsFile != NULL)
  {
    int fd;

#ifdef DEBUG
    printf("writing new bootsector to file %s\n", bsFile);
#endif

    /* write newboot to bsFile */
    if ((fd =
         open(bsFile, O_RDWR | O_TRUNC | O_CREAT | O_BINARY,
              S_IREAD | S_IWRITE)) < 0)
    {
      printf(" %s: can't create\"%s\"\nDOS errnum %d", pgm, bsFile, errno);
      exit(1);
    }
    if (write(fd, newboot, ((struct bootsectortype *)newboot)->bsBytesPerSec)
          != ((struct bootsectortype *)newboot)->bsBytesPerSec)
    {
      printf("Can't write %u bytes to %s\n",
               ((struct bootsectortype *)newboot)->bsBytesPerSec, bsFile);
      close(fd);
      unlink(bsFile);
      exit(1);
    }
    close(fd);
  }
  reset_drive(drive);
}

BOOL check_space(COUNT drive, BYTE * BlkBuffer)
{
  /* this should check, if on destination is enough space
     to hold command.com+ kernel.sys */

  UNREFERENCED_PARAMETER(drive);
  UNREFERENCED_PARAMETER(BlkBuffer);

  return TRUE;
}

BYTE copybuffer[COPY_SIZE];

BOOL copy(COUNT drive, BYTE * srcPath, BYTE * rootPath, BYTE * file)
{
  BYTE dest[SYS_MAXPATH], source[SYS_MAXPATH];
  unsigned ret;
  int fdin, fdout;
  ULONG copied = 0;
  struct stat fstatbuf;

  sprintf(dest, "%c:\\%s", 'A' + drive, file);
  strcpy(source, srcPath);
  if (rootPath != NULL) /* trick for comspec */
    strcat(source, file);

  if (stat(source, &fstatbuf))
  {
    printf("%s: \"%s\" not found\n", pgm, source);

    if ((rootPath != NULL) && (*rootPath) /* && (errno == ENOENT) */ )
    {
      sprintf(source, "%s%s", rootPath, file);
      printf("%s: Trying \"%s\"\n", pgm, source);
      if (stat(source, &fstatbuf))
      {
        printf("%s: \"%s\" not found\n", pgm, source);
        return FALSE;
      }
    }
    else
      return FALSE;
  }

  if ((fdin = open(source, O_RDONLY | O_BINARY)) < 0)
  {
    printf("%s: failed to open \"%s\"\n", pgm, source);
    return FALSE;
  }

  if ((fdout =
       open(dest, O_RDWR | O_TRUNC | O_CREAT | O_BINARY,
            S_IREAD | S_IWRITE)) < 0)
  {
    printf(" %s: can't create\"%s\"\nDOS errnum %d", pgm, dest, errno);
    close(fdin);
    return FALSE;
  }

  while ((ret = read(fdin, copybuffer, COPY_SIZE)) > 0)
  {
    if (write(fdout, copybuffer, ret) != ret)
    {
      printf("Can't write %u bytes to %s\n", ret, dest);
      close(fdout);
      unlink(dest);
      break;
    }
    copied += ret;
  }

#ifdef __TURBOC__
  {
    struct ftime ftime;
    getftime(fdin, &ftime);
    setftime(fdout, &ftime);
  }
#endif
#ifdef __WATCOMC__
  {
    unsigned date, time;	  
    _dos_getftime(fdin, &date, &time);
    _dos_setftime(fdout, date, time);
  }
#endif  

  close(fdin);
  close(fdout);

#ifdef _MSV_VER
  {
#include <utime.h>
    struct utimbuf utimb;

    utimb.actime =              /* access time */
        utimb.modtime = fstatbuf.st_mtime;      /* modification time */
    utime(dest, &utimb);
  };

#endif

  printf("%lu Bytes transferred", copied);

  return TRUE;
}

/* version 2.2 jeremyd 2001/9/20
   Changed so if no source given or only source drive (no path)
   given, then checks for kernel.sys & command.com in current
   path (of current drive or given drive) and if not there
   uses root (but only if source & destination drive are different).
   Fix printf to include count(ret) if copy can't write all requested bytes
*/
/* version 2.1a jeremyd 2001/8/19
   modified so takes optional 2nd parameter (similar to PC DOS)
   where if only 1 argument is given, assume to be destination drive,
   but if two arguments given, 1st is source (drive and/or path)
   and second is destination drive
*/

/* Revision 2.1 tomehlert 2001/4/26

    changed the file system detection code.
    

*/

/* Revision 2.0 tomehlert 2001/4/26
   
   no direct access to the disk any more, this is FORMAT's job
   no floppy.asm anymore, no segmentation problems.
   no access to partition tables
   
   instead copy boot sector using int25/int26 = absdiskread()/write
   
   if xxDOS is able to handle the disk, SYS should work
   
   additionally some space savers:
   
   replaced fopen() by open() 
   
   included (slighly modified) PRF.c from kernel
   
   size is no ~7500 byte vs. ~13690 before

*/
