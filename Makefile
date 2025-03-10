MODNAME := dpimod
MODVERSION = 0.0.1
TARGET := $(MODNAME).ko
PWD := $(CURDIR)
SRCDIR := $(PWD)/src
MAKESRC := $(SRCDIR)/Makefile
src_m = $(SRCDIR)/$(MODNAME).c

#The directory that contains the kernel sources or relevant build
KDIR := /lib/modules/$$(KVERSION)/build
#KDIR := ~/projects/huge_projects/linux

#Module will be installed here:
INST_MODDIR := /lib/modules/$(KVERSION)

#simple '=' means deferred assignment (DEB_ROOTDIR will be defined later)
INST_MODPATH = $(DEB_ROOTDIR)/DEBIAN/$(INST_MODDIR)

#Root DEBIAN dir where all package files are accumulated
DEB_ROOTDIR := $(PWD)/deb-pkg

DKMSDIR = $(PWD)/dkms
MODFULLNAME := $(MODNAME)-$(MODVERSION)
DKMS_PATH := $(DKMSDIR)/$(MODFULLNAME)
DKMS_CONF := $(DKMS_PATH)/dkms.conf
DEST_DKMS_DIR := /usr/src
DEST_DKMS_PATH := $(DEST_DKMS_DIR)/$(MODFULLNAME)

DEST_MODDIR := /var/lib/dkms
DEST_MODPATH := $(DEST_MODDIR)/$(MODNAME)/$(MODVERSION)
DEST_DEBDIR := $(DEST_MODPATH)/deb

TMP := /tmp
DEST_TMP := $(TMP)
SSH :=

# Dirty HACK for Debug purpose:
D := 192.168.122.64

ifdef D
ifeq "$(origin D)" "environment"
D :=
else
DEST_TMP := $(D):$(TMP)
DEST_DEBDIR := $(D):$(DEST_DEBDIR)
SSH := ssh
endif
endif

.PHONY: all modules clean dkms deploy install remove deb run stop
help:
	@echo Targets for DKMS building: deploy install remove deb run stop

all: modules clean
	@echo Find \'$(TARGET)\' in your work DIR
	@echo Run \'make modules\' to build in $(SRCDIR)
	@echo Run \'make clean\' to clean $(SRCDIR)

modules clean: $(MAKESRC)
	make -C $(SRCDIR) -f $(MAKESRC) $@
#	@if [ "$@" = "clean" ]; then \
#		rm $(MAKESRC); \
#	else \
#		(cp $(SRCDIR)/$(TARGET) $(PWD) || echo $(TARGET) does not exist); \
#	fi

$(MAKESRC): $(src_m)
	@echo Sources were changed. Remove the module...
	$(MAKE) remove
	echo '.PHONY: modules clean' > $(MAKESRC)
	echo '"KVERSION ?= $$(shell uname -r)" # For currently working kernel' >> $(MAKESRC)
#	echo KVERSION ?= 5.15.0-70-generic >> $(MAKESRC)
	echo  obj-m += $(MODNAME).o >> $(MAKESRC)
	echo modules: >> $(MAKESRC)
	echo '	make -C $(KDIR) M=$(DEST_DKMS_PATH) modules' >> $(MAKESRC)
	echo clean: >> $(MAKESRC)
	echo '	make -C $(KDIR) M=$(DEST_DKMS_PATH) clean' >> $(MAKESRC)

deb-pkg: $(INST_MODPATH)
$(INST_MODPATH):
	mkdir -p $(INST_MODPATH)

dkms: $(DKMS_PATH) $(MAKESRC)

$(DKMS_PATH):
	mkdir -p $(DKMS_PATH)
	rsync -a $(SRCDIR)/* $(DKMS_PATH)
	echo PACKAGE_NAME="$(MODNAME)" > $(DKMS_CONF)
	echo PACKAGE_VERSION="$(MODVERSION)" >> $(DKMS_CONF)
	echo CLEAN='"make clean KVERSION=$$kernelver"' >> $(DKMS_CONF)
	echo MAKE[0]='"make modules --debug KVERSION=$$kernelver"' >> $(DKMS_CONF)
	echo BUILT_MODULE_NAME[0]="$(MODNAME)" >> $(DKMS_CONF)
	echo DEST_MODULE_LOCATION[0]="/updates" >> $(DKMS_CONF)
	echo AUTOINSTALL="yes" >> $(DKMS_CONF)

deploy: dkms
	rsync -a $(DKMS_PATH) $(DEST_TMP)
	$(SSH) $(D) sudo rsync -a $(TMP)/$(MODFULLNAME) $(DEST_DKMS_DIR)
	$(SSH) $(D) rm -rf $(TMP)/$(MODFULLNAME)

install: deploy
	$(SSH) $(D) sudo dkms add -m $(MODNAME) -v $(MODVERSION) || :
	$(SSH) $(D) sudo dkms build -j 1 --verbose -m $(MODNAME) -v $(MODVERSION) || \
        $(SSH) $(D) sudo dkms build -j 1 --verbose -m $(MODNAME) -v $(MODVERSION) #Strange bug in dkms (double build is needed)
	$(SSH) $(D) sudo dkms install -m $(MODNAME) -v $(MODVERSION)
	$(SSH) $(D) sudo dkms status

remove: stop
	$(SSH) $(D) sudo dkms remove --verbose -m $(MODNAME) -v $(MODVERSION) --all || :
	$(SSH) $(D) sudo dkms status
	$(SSH) $(D) sudo rm -rf $(DEST_DKMS_PATH)

deb: install deb-pkg
	$(SSH) $(D) sudo dkms mkdeb -m $(MODNAME) -v $(MODVERSION)
	rsync -a $(DEST_DEBDIR)/*.deb $(DEB_ROOTDIR)

run: install
	$(SSH) $(D) sudo modprobe $(MODNAME)
	$(SSH) $(D) sudo dmesg --kernel

stop:
	$(SSH) $(D) sudo rmmod $(MODNAME) || :
	$(SSH) $(D) sudo dmesg --kernel


# On remote side:
#	mkdir -p /lib/modules/user_modules/
#	mv /tmp/dpi_mod.ko user_modules/
#	ln -s user_modules/dpi_mod.ko dpi_mod.ko
#	depmod -a
#	modprobe dpi_mod
#	dmesg
#	journalctl --since "1 hour ago" | grep kernel
#	lsmod | grep dpi
#	rmmod dpi_mod
#	lsmod | grep dpi
#	journalctl --since "1 hour ago" | grep kernel

cleanall:
#cleanall: clean
	rm -rf $(DKMSDIR)
	rm -rf $(DEB_ROOTDIR)
	rm $(MAKESRC)
