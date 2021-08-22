TARGET := pcsx-redux
BUILD ?= Release
DESTDIR ?= /usr/local

UNAME_S := $(shell uname -s)
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))
CC_IS_CLANG := $(shell $(CC) --version | grep -q clang && echo true || echo false)

PACKAGES := glfw3 libavcodec libavformat libavutil libswresample libuv sdl2 zlib freetype2

LOCALES := fr

CXXFLAGS += -std=c++2a
CPPFLAGS += `pkg-config --cflags $(PACKAGES)`
CPPFLAGS += -I.
CPPFLAGS += -Isrc
CPPFLAGS += -Ithird_party
CPPFLAGS += -Ithird_party/fmt/include/
CPPFLAGS += -Ithird_party/gl3w
CPPFLAGS += -Ithird_party/googletest/googletest/include
CPPFLAGS += -Ithird_party/imgui
CPPFLAGS += -Ithird_party/imgui/backends
CPPFLAGS += -Ithird_party/imgui/examples
CPPFLAGS += -Ithird_party/imgui/misc/cpp
CPPFLAGS += -Ithird_party/imgui_club
CPPFLAGS += -Ithird_party/http-parser
CPPFLAGS += -Ithird_party/libelfin
CPPFLAGS += -Ithird_party/luajit/src
CPPFLAGS += -Ithird_party/luv/src
CPPFLAGS += -Ithird_party/luv/deps/lua-compat-5.3/c-api
CPPFLAGS += -Ithird_party/ucl -Ithird_party/ucl/include
CPPFLAGS += -Ithird_party/zep/extensions
CPPFLAGS += -Ithird_party/zep/include
CPPFLAGS += -Ithird_party/zstr/src
CPPFLAGS += -Ithird_party/xbyak/xbyak
CPPFLAGS += -g
CPPFLAGS += -DIMGUI_IMPL_OPENGL_LOADER_GL3W -DIMGUI_ENABLE_FREETYPE
CPPFLAGS += -DZEP_FEATURE_CPP_FILE_SYSTEM
IMGUI_CPPFLAGS += -include src/forced-includes/imgui.h

CPPFLAGS_Release += -O3
CPPFLAGS_Debug += -O0
CPPFLAGS_Coverage += -O0
CPPFLAGS_Coverage += -fprofile-instr-generate -fcoverage-mapping
CPPFLAGS_asan += -O1 -fsanitize=address -fno-omit-frame-pointer
CPPFLAGS_ReleaseWithTracy += -O3 -DTRACY_ENABLE

ifeq ($(CC_IS_CLANG),true)
    CXXFLAGS += -fcoroutines-ts
    LUAJIT_CFLAGS = -fno-stack-check
else
    CXXFLAGS += -fcoroutines
endif

ifeq ($(UNAME_S),Darwin)
    CPPFLAGS += -mmacosx-version-min=10.15
    CPPFLAGS += -stdlib=libc++
endif

LDFLAGS += `pkg-config --libs $(PACKAGES)`

ifeq ($(UNAME_S),Darwin)
    LDFLAGS += -lc++ -framework GLUT -framework OpenGL -framework CoreFoundation -framework Cocoa
    LDFLAGS += -mmacosx-version-min=10.15
else
    LDFLAGS += -lstdc++fs
    LDFLAGS += -lGL -lX11
endif

LDFLAGS += third_party/luajit/src/libluajit.a
LDFLAGS += -ldl
LDFLAGS += -g

LDFLAGS_Coverage += -fprofile-instr-generate -fcoverage-mapping
LDFLAGS_asan += -fsanitize=address

CPPFLAGS += $(CPPFLAGS_$(BUILD)) -pthread
LDFLAGS += $(LDFLAGS_$(BUILD)) -pthread

LD := $(CXX)

SRCS := $(call rwildcard,src/,*.cc)
SRCS += third_party/fmt/src/os.cc third_party/fmt/src/format.cc
IMGUI_SRCS += $(wildcard third_party/imgui/*.cpp)
SRCS += $(IMGUI_SRCS)
SRCS += $(wildcard third_party/libelfin/*.cc)
SRCS += third_party/gl3w/GL/gl3w.c
SRCS += third_party/imgui/backends/imgui_impl_opengl3.cpp
SRCS += third_party/imgui/backends/imgui_impl_glfw.cpp
SRCS += third_party/imgui/misc/cpp/imgui_stdlib.cpp
SRCS += third_party/imgui/misc/freetype/imgui_freetype.cpp
SRCS += third_party/imgui_lua_bindings/imgui_lua_bindings.cpp
SRCS += third_party/http-parser/http_parser.c
SRCS += third_party/luv/src/luv.c
SRCS += third_party/tracy/TracyClient.cpp
SRCS += third_party/ucl/src/n2e_99.c third_party/ucl/src/alloc.c
SRCS += third_party/zep/extensions/repl/mode_repl.cpp
SRCS += $(wildcard third_party/zep/src/*.cpp)
SRCS += third_party/zep/src/mcommon/animation/timer.cpp
SRCS += third_party/zep/src/mcommon/file/path.cpp
SRCS += third_party/zep/src/mcommon/string/stringutils.cpp
ifeq ($(UNAME_S),Darwin)
    SRCS += src/main/complain.mm
endif
OBJECTS := $(patsubst %.c,%.o,$(filter %.c,$(SRCS)))
OBJECTS += $(patsubst %.cc,%.o,$(filter %.cc,$(SRCS)))
OBJECTS += $(patsubst %.cpp,%.o,$(filter %.cpp,$(SRCS)))
OBJECTS += $(patsubst %.mm,%.o,$(filter %.mm,$(SRCS)))
OBJECTS += third_party/luajit/src/libluajit.a

NONMAIN_OBJECTS := $(filter-out src/main/mainthunk.o,$(OBJECTS))
IMGUI_OBJECTS := $(patsubst %.cpp,%.o,$(filter %.cpp,$(IMGUI_SRCS)))

$(IMGUI_OBJECTS): EXTRA_CPPFLAGS := $(IMGUI_CPPFLAGS)

TESTS_SRC := $(call rwildcard,tests/,*.cc)
TESTS := $(patsubst %.cc,%,$(TESTS_SRC))

CP ?= cp
MKDIRP ?= mkdir -p

all: dep $(TARGET)

strip: all
	strip $(TARGET)

openbios:
	$(MAKE) $(MAKEOPTS) -C src/mips/openbios

install: all strip
	$(MKDIRP) $(DESTDIR)/bin
	$(MKDIRP) $(DESTDIR)/share/applications
	$(MKDIRP) $(DESTDIR)/share/icons/hicolor/256x256/apps
	$(MKDIRP) $(DESTDIR)/share/pcsx-redux/fonts
	$(MKDIRP) $(DESTDIR)/share/pcsx-redux/i18n
	$(MKDIRP) $(DESTDIR)/share/pcsx-redux/resources
	$(CP) $(TARGET) $(DESTDIR)/bin
	$(CP) resources/pcsx-redux.desktop $(DESTDIR)/share/applications
	convert resources/pcsx-redux.ico[0] -alpha on -background none $(DESTDIR)/share/icons/hicolor/256x256/apps/pcsx-redux.png
	$(CP) third_party/noto/* $(DESTDIR)/share/pcsx-redux/fonts
	$(CP) i18n/*.po $(DESTDIR)/share/pcsx-redux/i18n
	$(CP) resources/*.ico $(DESTDIR)/share/pcsx-redux/resources
	$(CP) third_party/SDL_GameControllerDB/LICENSE $(DESTDIR)/share/pcsx-redux/resources
	$(CP) third_party/SDL_GameControllerDB/gamecontrollerdb.txt $(DESTDIR)/share/pcsx-redux/resources

install-openbios: openbios
	$(MKDIRP) $(DESTDIR)/share/pcsx-redux/resources
	$(CP) src/mips/openbios/openbios.bin $(DESTDIR)/share/pcsx-redux/resources
	zip -j src/mips/openbios/openbios.zip src/mips/openbios/openbios.elf

appimage:
	rm -rf AppDir
	DESTDIR=AppDir/usr $(MAKE) $(MAKEOPTS) install
	appimage-builder --skip-tests

third_party/luajit/src/libluajit.a:
	$(MAKE) $(MAKEOPTS) -C third_party/luajit/src amalg CC=$(CC) BUILDMODE=static CFLAGS=$(LUAJIT_CFLAGS) XCFLAGS=-DLUAJIT_ENABLE_GC64 MACOSX_DEPLOYMENT_TARGET=10.15

$(TARGET): $(OBJECTS)
	$(LD) -o $@ $(OBJECTS) $(LDFLAGS)

%.o: %.c
	$(CC) -c -o $@ $< $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CFLAGS)

%.o: %.cc
	$(CXX) -c -o $@ $< $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CXXFLAGS)

%.o: %.cpp
	$(CXX) -c -o $@ $< $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CXXFLAGS)

%.o: %.mm
	$(CC) -c -o $@ $< $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CFLAGS)

%.dep: %.c
	$(CC) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CFLAGS) -M -MT $(addsuffix .o, $(basename $@)) -MF $@ $<

%.dep: %.cc
	$(CXX) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CXXFLAGS) -M -MT $(addsuffix .o, $(basename $@)) -MF $@ $<

%.dep: %.cpp
	$(CXX) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CXXFLAGS) -M -MT $(addsuffix .o, $(basename $@)) -MF $@ $<

clean:
	rm -f $(OBJECTS) $(TARGET) $(DEPS) gtest-all.o
	$(MAKE) -C third_party/luajit clean

gtest-all.o: $(wildcard third_party/googletest/googletest/src/*.cc)
	$(CXX) -O3 -g $(CXXFLAGS) -Ithird_party/googletest/googletest -Ithird_party/googletest/googletest/include -c third_party/googletest/googletest/src/gtest-all.cc

gitclean:
	git clean -f -d -x
	git submodule foreach --recursive git clean -f -d -x

define msgmerge
msgmerge --update i18n/$(1).po i18n/pcsx-redux.pot
endef

regen-i18n:
	find src -name *.cc -or -name *.c -or -name *.h | sort -u > pcsx-src-list.txt
	xgettext --keyword=_ --language=C++ --add-comments --sort-output -o i18n/pcsx-redux.pot --omit-header -f pcsx-src-list.txt
	rm pcsx-src-list.txt
	$(foreach l,$(LOCALES),$(call msgmerge,$(l)))

pcsx-redux-tests: $(foreach t,$(TESTS),$(t).o) $(NONMAIN_OBJECTS) gtest-all.o
	$(LD) -o pcsx-redux-tests $(NONMAIN_OBJECTS) gtest-all.o $(foreach t,$(TESTS),$(t).o) -Ithird_party/googletest/googletest/include third_party/googletest/googletest/src/gtest_main.cc $(LDFLAGS)

runtests: pcsx-redux-tests
	./pcsx-redux-tests

psyq-obj-parser: $(NONMAIN_OBJECTS) tools/psyq-obj-parser/psyq-obj-parser.cc
	$(LD) -o $@ $(NONMAIN_OBJECTS) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) tools/psyq-obj-parser/psyq-obj-parser.cc -Ithird_party/ELFIO

ps1-packer: $(NONMAIN_OBJECTS) tools/ps1-packer/ps1-packer.cc
	$(LD) -o $@ $(NONMAIN_OBJECTS) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) tools/ps1-packer/ps1-packer.cc

.PHONY: all dep clean gitclean regen-i18n runtests openbios install strip appimage

DEPS += $(patsubst %.c,%.dep,$(filter %.c,$(SRCS)))
DEPS := $(patsubst %.cc,%.dep,$(filter %.cc,$(SRCS)))
DEPS += $(patsubst %.cpp,%.dep,$(filter %.cpp,$(SRCS)))

dep: $(DEPS)

ifneq ($(MAKECMDGOALS), regen-i18n)
ifneq ($(MAKECMDGOALS), clean)
ifneq ($(MAKECMDGOALS), gitclean)
-include $(DEPS)
endif
endif
endif
