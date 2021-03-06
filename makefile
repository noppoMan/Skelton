CLibUv=CLibUv-*
HTTPParser=HTTPParser-*
CURIParser=CURIParser-*

BUILDOPTS=-Xlinker -L/usr/lib \
	-Xcc -IPackages/$(CLibUv) \
	-Xcc -IPackages/$(HTTPParser) \
	-Xcc -IPackages/$(CURIParser)

SWIFTC=swiftc
SWIFT=swift
ifdef SWIFTPATH
  SWIFTC=$(SWIFTPATH)/bin/swiftc
  SWIFT=$(SWIFTPATH)/bin/swift
endif
OS := $(shell uname)
ifeq ($(OS),Darwin)
  SWIFTC=xcrun -sdk macosx swiftc
  BUILDOPTS=-Xlinker -L/usr/local/lib -Xcc -I/usr/local/include
endif

all: release

debug:
	$(SWIFT) build $(BUILDOPTS)

release:
	$(SWIFT) build $(BUILDOPTS) --configuration=release

test:
	$(SWIFT) test $(BUILDOPTS)
