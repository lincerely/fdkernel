#
# WATCOM.MAK - kernel compiler options for Open Watcom on Linux (cross-compile)
#

# Get definitions from watcom.mak, then override
include "../mkfiles/watcom.mak"

DIRSEP=/
INCLUDEPATH=$(COMPILERPATH)$(DIRSEP)h
RM=rm -f
CP=cp
ECHOTO=echo>>
INITPATCH=@echo > /dev/null
CLDEF=1
CLT=gcc -DDOSC_TIME_H -I../../hdr -o $^@
CLC=$(CLT)
CFLAGST=-fo=$^@ $(CFLAGST)
ALLCFLAGS=-fo=$^@ $(ALLCFLAGS) 
XLINK=$(XLINK) debug all op symfile format dos option map,statics,verbose F { $(OBJS) } L ../lib/device.lib N kernel.exe $#
