# The following libraries require building:
#- python
#- date_time
#- filesystem
#- graph
#- iostreams
#- math
#- mpi
#- program_options
#- python
#- regex
#- serialization
#- signals
#- system
#- test
#- thread
#- wave

CONFIGURE_FLAGS=--with-toolset=gcc
BUILD_VARIANTS = variant=release threading=multi debug-symbols=on link=static runtime-link=static
BUILD_VARIANTS += cxxflags="$(CXXFLAGS)" cflags="$(CFLAGS)" linkflags="$(LDFLAGS)"

PREFIX_FLAGS=--prefix=$(SYSROOT_DIR) --includedir=$(SYSROOT_DIR)/include --includedir=$(SYSROOT_DIR)/include/python27 --libdir=$(SYSROOT_DIR)/lib
BUILD_DIR_FLAGS=--build-dir=$(BUILD_DIR)/boost/build --stagedir=$(BUILD_DIR)/boost/stage


ifeq ($(findstring mingw32,$(HOST)), mingw32)
CROSS_COMPILE_ARGS=--user-config=user-config-mingw.jam target-os=windows threadapi=win32
W32=_win32
endif

ifeq ($(findstring enable,$(WITH_UNIVERSAL_BUILD)), enable)
BUILD_VARIANTS += cxxflags="-isysroot \\Developer\\SDKs\\MacOSX10.4u.sdk -mmacosx-version-min=10.3.9 -arch ppc7400 -arch i386" cflags="-arch ppc7400 -arch i386" linkflags="-arch ppc7400 -arch i386" architecture=combined
# fix up the *.a files so they are really universal binaries using ranlib
# otherwise, they do not show up as universal since bjam uses "ar" instead
# of 'libtool'
RANLIB_COMMAND=ranlib $(SYSROOT_DIR)/lib/libboost*.a
else
RANLIB_COMMAND=true
endif

BOOST_TARGET_LIBS = \
				   $(BUILD_DIR)/boost/stage/lib/libboost_python.a \
				   $(BUILD_DIR)/boost/stage/lib/libboost_thread$(W32).a \
				   $(BUILD_DIR)/boost/stage/lib/libboost_system.a \
				   $(BUILD_DIR)/boost/stage/lib/libboost_filesystem.a \
				   $(BUILD_DIR)/boost/stage/lib/libboost_date_time.a

BOOST_SYSROOT_LIBS = \
				   $(SYSROOT_DIR)/lib/libboost_python.a \
				   $(SYSROOT_DIR)/lib/libboost_thread$(W32).a \
				   $(SYSROOT_DIR)/lib/libboost_system.a \
				   $(SYSROOT_DIR)/lib/libboost_filesystem.a \
				   $(SYSROOT_DIR)/lib/libboost_date_time.a

FEATURE_FLAGS= \
			   --with-python \
			   --with-date_time \
			   --with-filesystem \
			   --with-iostreams \
			   --with-program_options \
			   --with-serialization \
			   --with-signals \
			   --with-system \
			   --with-thread

BUILD_FLAGS=$(CROSS_COMPILE_ARGS) -d2 --layout=system $(BUILD_VARIANTS) $(BUILD_DIR_FLAGS) $(PREFIX_FLAGS) $(FEATURE_FLAGS)


.PHONY: build
build: user-config-mingw.jam $(BOOST_SYSROOT_LIBS)
	@echo .........Boost libraries are built..........

user-config-mingw.jam:
	if [ ! -z "$(CROSS_COMPILE_ARGS)" ]; then \
		echo -ne "using gcc : m : $(CXX) : <compileflags>-I$(INCLUDE_DIR) <linkflags>-L$(LIB_DIR) ;\n" > user-config-mingw.jam ; \
		echo -ne "using python : 2.7 : $(SYSROOT_DIR)/bin/python : $(INCLUDE_DIR)/python27 : $(LIB_DIR) : <python-debugging>off ;" >> user-config-mingw.jam ; \
	fi
	touch user-config-mingw.jam

#### (I) Build libraries
# check jam0
tools/build/v2/engine/src/bootstrap/jam0:
	cd tools/build/v2/engine/src && ./build.sh

# check bjam
bjam: tools/build/v2/engine/src/bootstrap/jam0
	./bootstrap.sh $(CONFIGURE_FLAGS) $(PREFIX_FLAGS) --with-python=$(SYSROOT_DIR)

# build boost
$(BOOST_TARGET_LIBS): bjam
	./bjam  $(SMP_MFLAGS) $(BUILD_FLAGS) stage

$(BOOST_SYSROOT_LIBS): $(BOOST_TARGET_LIBS)
	./bjam $(BUILD_FLAGS) install
	@echo ...........Stage: $@ ...................................

.PHONY: clean
clean:
	# check bjam
	if [ -e bjam ]; then \
		./bjam $(BUILD_FLAGS) clean; \
	fi
	# clean config & log
	rm -fr bin.v2/ project-config.jam* tools/build/v2/engine/src/config.log
	# clean bjam
	rm -fr bjam tools/build/v2/engine/src/bin.*/
	#clean jam0
	rm -fr tools/build/v2/engine/src/bootstrap/
	rm -f user-config-mingw.jam
