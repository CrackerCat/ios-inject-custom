host_arch := arm64
host_machine := arm64

CC := $(shell xcrun --sdk iphoneos -f clang) -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=8.0 -arch $(host_machine)
CFLAGS := -Wall -pipe -Os
LDFLAGS := -Wl,-dead_strip
STRIP := $(shell xcrun --sdk iphoneos -f strip) -Sx
CODESIGN := $(shell xcrun --sdk iphoneos -f codesign) -f -s "iPhone Developer"

frida_version := 12.9.4
frida_os_arch := ios-$(host_arch)
frida_core_devkit_url := https://github.com/frida/frida/releases/download/$(frida_version)/frida-core-devkit-$(frida_version)-$(frida_os_arch).tar.xz
frida_gum_devkit_url := https://github.com/frida/frida/releases/download/$(frida_version)/frida-gum-devkit-$(frida_version)-$(frida_os_arch).tar.xz

all: bin/inject bin/agent.dylib bin/victim

deploy: bin/inject bin/agent.dylib bin/victim
	ssh iphone "rm -rf /var/root/ios-inject-example"
	scp -r bin iphone:/var/root/ios-inject-example

bin/inject: inject.c ext/frida-core/.stamp
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -I./ext/frida-core inject.c -o $@ -L./ext/frida-core -lfrida-core -Wl,-framework,Foundation,-framework,UIKit -lresolv $(LDFLAGS)
	$(STRIP) $@
	$(CODESIGN) --entitlements inject.xcent $@

bin/agent.dylib: agent.c ext/frida-gum/.stamp
	@mkdir -p $(@D)
	$(CC) -shared -Wl,-exported_symbol,_example_agent_main $(CFLAGS) -I./ext/frida-gum agent.c -o $@ -L./ext/frida-gum -lfrida-gum $(LDFLAGS)
	$(STRIP) $@
	$(CODESIGN) $@

bin/victim: victim.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) victim.c -o $@ $(LDFLAGS)
	$(STRIP) $@
	$(CODESIGN) $@

ext/frida-core/.stamp:
	@mkdir -p $(@D)
	@rm -f $(@D)/*
	curl -Ls $(frida_core_devkit_url) | xz -d | tar -C $(@D) -xf -
	@touch $@

ext/frida-gum/.stamp:
	@mkdir -p $(@D)
	@rm -f $(@D)/*
	curl -Ls $(frida_gum_devkit_url) | xz -d | tar -C $(@D) -xf -
	@touch $@

.PHONY: all deploy
