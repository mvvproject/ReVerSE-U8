#
# makefile for CC65 runtime library
#

.SUFFIXES: .o .obj .s .c

# Defines for executables. AR is used within this makefile, the others are
# passed to the submakes and contain paths relative to the subdirectories
# handled by the make subprocesses.
AR = ar65
AS = ca65
CC = cc65
LD = ld65

# List of all targets
#ALLTARGETS =   	apple2 		\
#		apple2enh	\
#       	       	atari  		\
#       	       	atmos  		\
#                c16    		\
#       	       	c128   		\
#       	       	c64    		\
#       	       	cbm510 		\
#       	       	cbm610 		\
#       	       	geos   		\
#		lynx		\
#                nes     	\
#       	       	pet    		\
#       	       	plus4   	\
#		supervision	\
#		vic20
ALLTARGETS = vector

#-----------------------------------------------------------------------------

.PHONY:	all
all:
	for tgt in $(ALLTARGETS); do		\
	    $(MAKE) clean "$$tgt"lib || exit 1;	\
	done

# ----------------------------------------------------------------------------
# Vector-06C floppy emu

vectorlib:
	for i in vector common runtime; do \
	    $(MAKE) SYS=none -C $$i || exit 1; \
	    $(AR) a vector.lib $$i/*.o;\
	done
	mv vector/crt0.o vector.o

#-----------------------------------------------------------------------------
# Dummy targets

.PHONY: clean
clean:
	@for i in common runtime $(ALLTARGETS); do\
       	   $(MAKE) -C $$i clean;			      		   	\
	done

.PHONY: zap
zap:	clean
	@for i in common runtime $(ALLTARGETS); do\
	   $(MAKE) -C $$i zap;     	    	       	      	   		\
	done
	@$(RM) *.o *.emd *.joy *.lib *.tgi *.ser *.mou



