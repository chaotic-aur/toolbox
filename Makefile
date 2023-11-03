#!/usr/bin/env make
ifeq ($(PREFIX),)
    PREFIX := /usr/local
endif

LIBS = \
	aur \
	base-make \
	cleanup \
	database \
	deploy \
	interfere \
	mirror \
	package-make \
	package-makedir \
	package-prepare \
	pkgrel-incrementer \
	routines \
	routines-garuda \
	routines-tkg \
	routines-tkg-wine \
	sync \
	utils	
ROUTINES = \
	hourly \
	morning \
	afternoon \
	nightly \
	midnight \
	garuda \
	tkg-kernels \
	tkg-wine

GUEST_ETC = pacman.conf makepkg.conf.append
GUEST_BIN = internal-makepkg internal-makepkg-depends x11-wrapper

dir_guard=@install -dm755 "$(@D)"

build/chaotic.elf: src/chaotic.c
	$(dir_guard)
	gcc -DPREFIX="\"$(PREFIX)\"" $< -o $@

$(DESTDIR)$(PREFIX)/bin/chaotic.sh: src/chaotic.sh
	$(dir_guard)
	install -m755 $< $@

$(DESTDIR)$(PREFIX)/bin/chaotic: build/chaotic.elf
	$(dir_guard)
	install -o root -g chaotic_op -m4750 $< $@

$(DESTDIR)$(PREFIX)/lib/chaotic/%.sh: src/lib/%.sh
	$(dir_guard)
	install -m755 $< $@

$(DESTDIR)$(PREFIX)/lib/chaotic/guest/etc/%: guest/etc/%
	$(dir_guard)
	install -m644 $< $@

$(DESTDIR)$(PREFIX)/lib/chaotic/guest/bin/%: guest/bin/%
	$(dir_guard)
	install -m755 $< $@

$(DESTDIR)/var/lib/chaotic/interfere:
	$(dir_guard)
	cd "$(@D)" && git clone 'https://github.com/chaotic-aur/interfere.git' interfere

$(DESTDIR)/var/lib/chaotic/packages:
	$(dir_guard)
	cd "$(@D)" && git clone 'https://github.com/chaotic-aur/packages.git' packages

$(DESTDIR)/var/cache/chaotic:
	@install -dm755 $@

$(DESTDIR)/usr/lib/systemd/system/%: services/%
	install -o root -g root -m755 $< $@

build: build/chaotic.elf

install: \
	$(foreach f, $(LIBS), $(DESTDIR)$(PREFIX)/lib/chaotic/${f}.sh) \
	$(foreach l, $(GUEST_ETC), $(DESTDIR)$(PREFIX)/lib/chaotic/guest/etc/${l}) \
	$(foreach l, $(GUEST_BIN), $(DESTDIR)$(PREFIX)/lib/chaotic/guest/bin/${l}) \
	$(DESTDIR)$(PREFIX)/bin/chaotic.sh \
	$(DESTDIR)$(PREFIX)/bin/chaotic \
	$(DESTDIR)/var/lib/chaotic/interfere \
	$(DESTDIR)/var/lib/chaotic/packages \
	$(DESTDIR)/var/cache/chaotic

install-services: \
	$(foreach s, $(ROUTINES), $(DESTDIR)/usr/lib/systemd/system/chaotic-${s}.service) \
	$(foreach s, $(ROUTINES), $(DESTDIR)/usr/lib/systemd/system/chaotic-${s}.timer)
	systemctl daemon-reload

.PHONY: install install-services build
