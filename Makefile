
# Target platform (linux, 3ds, nspire, emscripten)
TARGET?=linux

# set to 1 to use SDL1.2
SDL_VER?=2

# set to 1 to embed resources
EMBED_RESOURCES?=0

# NSpire toolchain configuration
ifeq ($(TARGET),nspire)
    # NSpire toolchain
    GCC = nspire-gcc
    AS  = nspire-as
    GXX = nspire-g++
    LD  = nspire-ld
    GENZEHN = genzehn
    
    # Compiler flags for NSpire
    GCCFLAGS = -Wall -W -marm -Os
    ZEHNFLAGS = --name "ccleste"
    
    # Override default compiler/linker
    CC := $(GCC)
    CXX := $(GXX)
    
    # Force embedded resources for NSpire
    EMBED_RESOURCES = 1
    
    # NSpire-specific flags
    CFLAGS += $(GCCFLAGS)
endif

# List of resources to embed
RESOURCE_BMP=\
    data/gfx.bmp \
    data/font.bmp

RESOURCE_WAV=
#     data/snd0.wav \
#     data/snd1.wav \
#     data/snd2.wav \
#     data/snd3.wav \
#     data/snd4.wav \
#     data/snd5.wav \
#     data/snd6.wav \
#     data/snd7.wav \
#     data/snd8.wav \
#     data/snd9.wav \
#     data/snd13.wav \
#     data/snd14.wav \
#     data/snd15.wav \
#     data/snd16.wav \
#     data/snd23.wav \
#     data/snd35.wav \
#     data/snd37.wav \
#     data/snd38.wav \
#     data/snd40.wav \
#     data/snd50.wav \
#     data/snd51.wav \
#     data/snd54.wav \
#     data/snd55.wav

RESOURCE_OGG=
#     data/mus0.ogg \
#     data/mus10.ogg \
#     data/mus20.ogg \
#     data/mus30.ogg \
#     data/mus40.ogg

# Generate C array file names
RESOURCE_C_BMP=$(RESOURCE_BMP:data/%.bmp=resources/%_bmp.c)
RESOURCE_C_WAV=$(RESOURCE_WAV:data/%.wav=resources/%_wav.c)
RESOURCE_C_OGG=$(RESOURCE_OGG:data/%.ogg=resources/%_ogg.c)
RESOURCE_C=$(RESOURCE_C_BMP) $(RESOURCE_C_WAV) $(RESOURCE_C_OGG)

# Rule to generate C arrays from binary files
resources/%_bmp.c: data/%.bmp bin2c.py
	@mkdir -p resources
	python3 bin2c.py $< $@ $(notdir $*)_bmp

# NSpire-specific configurations
ifeq ($(TARGET),nspire)
    # NSpire SDL configuration
#     NSPIRE_SDK=/home/velzie/src/Ndless/ndless-sdk
#     NSPIRE_SDL_CONFIG=$(NSPIRE_SDK)/bin/sdl-config
#     CFLAGS += -I$(NSPIRE_SDK)/include/SDL
#     LDFLAGS += -lSDL
endif

resources/%_wav.c: data/%.wav bin2c.py
	@mkdir -p resources
	python3 bin2c.py $< $@ $(notdir $*)_wav

resources/%_ogg.c: data/%.ogg bin2c.py
	@mkdir -p resources
	python3 bin2c.py $< $@ $(notdir $*)_ogg

# Conditional compilation flags
ifeq ($(EMBED_RESOURCES),1)
    CFLAGS += -DEMBED_RESOURCES
    RESOURCE_OBJS=$(RESOURCE_C:.c=.o)
else
    RESOURCE_OBJS=
endif

ifeq ($(SDL_VER),2)
	SDL_CONFIG=sdl2-config
	SDL_LD=-lSDL2 -lSDL2_mixer
else
ifeq ($(SDL_VER),1)
	SDL_CONFIG=sdl-config
	SDL_LD=-lSDL
else
	SDL_CONFIG=$(error "invalid SDL version '$(SDL_VER)'. possible values are '1' and '2'")
endif
endif

CFLAGS+=-Wall -g -O2 `$(SDL_CONFIG) --cflags`
LDFLAGS=$(SDL_LD)
CELESTE_CC=$(CC)

ifneq ($(USE_FIXEDP),)
	OUT=ccleste-fixedp
	CELESTE_OBJ=celeste-fixedp.o
	CFLAGS+=-DCELESTE_P8_FIXEDP
	CELESTE_CC=$(CXX)
else
	OUT=ccleste
	CELESTE_OBJ=celeste.o
	LDFLAGS+=-lm
endif

# Output filename based on target
ifeq ($(TARGET),nspire)
    OUT = ccleste.tns
    ELF_OUT = ccleste.elf
else
    ELF_OUT = $(OUT).elf
endif

ifneq ($(HACKED_BALLOONS),)
	CFLAGS+=-DCELESTE_P8_HACKED_BALLOONS
endif

# NSpire target build rules
ifeq ($(TARGET),nspire)
    # NSpire build target
    all: $(OUT)
    
    # Compile C files for NSpire
    %.o: %.c
	    $(GCC) $(GCCFLAGS) $(CFLAGS) -c $<
    
    # Compile C++ files for NSpire
    %.o: %.cpp
	    $(GXX) $(GCCFLAGS) $(CFLAGS) -c $<
    
    # Compile assembly files for NSpire
    %.o: %.S
	    $(AS) -c $<
    
    # Compile resource C files for NSpire
    resources/%.o: resources/%.c
	    $(GCC) $(GCCFLAGS) $(CFLAGS) -c -o $@ $<
    
    # Link ELF file for NSpire
    $(ELF_OUT): sdl12main.c $(CELESTE_OBJ) celeste.h sdl20compat.inc.c $(RESOURCE_OBJS)
	    mkdir -p dist
	    $(GCC) $(GCCFLAGS) $(CFLAGS) sdl12main.c $(CELESTE_OBJ) $(RESOURCE_OBJS) -o dist/$@ $(LDFLAGS)
    
    # Package as TNS file for NSpire
    $(OUT): $(ELF_OUT)
		$(GENZEHN) --input dist/$< --output dist/$@ $(ZEHNFLAGS)
		make-prg dist/$@ dist/$(OUT).prg
    
    # Clean target for NSpire
    clean:
	    $(RM) *.o dist/$(OUT) dist/$(ELF_OUT)
	    $(RM) -r resources dist
	    @echo "Cleaned NSpire build files"

else
    # Existing build rules for other targets
    all: $(OUT)

$(OUT): sdl12main.c $(CELESTE_OBJ) celeste.h sdl20compat.inc.c $(RESOURCE_OBJS)
	$(CC) $(CFLAGS) sdl12main.c $(CELESTE_OBJ) $(RESOURCE_OBJS) -o $(OUT) $(LDFLAGS)

$(CELESTE_OBJ): celeste.c celeste.h
	$(CELESTE_CC) $(CFLAGS) -c -o $(CELESTE_OBJ) celeste.c

# Rule to compile resource C files
resources/%.o: resources/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	$(RM) ccleste ccleste-fixedp celeste.o celeste-fixedp.o
	$(RM) -r resources
	@echo "Skipping 3DS clean (DEVKITARM not set)"
endif  # End of NSpire target conditional
