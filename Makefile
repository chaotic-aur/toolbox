#!/usr/bin/env make
ifeq ($(PREFIX),)
    PREFIX := /usr/local
endif

LIBS = \
	aur \
	cleanup \
	db-bump \
	deploy \
	interfere \
	keyring \
	lower-prepare \
	makepkg-gen-bash \
	makepkg-run-nspawn \
	mirror \
	queue-run-nspawn \
	routines \
	sync	
GUEST_ETC = pacman makepkg
GUEST_BIN = internal-makepkg x11-wrapper

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

$(DESTDIR)$(PREFIX)/lib/chaotic/guest/etc/%.conf: guest/etc/%.conf
	$(dir_guard)
	install -m644 $< $@

$(DESTDIR)$(PREFIX)/lib/chaotic/guest/bin/%: guest/bin/%
	$(dir_guard)
	install -m755 $< $@

$(DESTDIR)/var/lib/chaotic/interfere:
	$(dir_guard)
	cd "$(@D)" && git clone 'https://github.com/chaotic-aur/interfere.git' interfere

$(DESTDIR)/var/cache/chaotic:
	@install -dm755 $@

$(DESTDIR)/etc/chaotic/gnupg:
	@install -o root -g root -dm700 $@
	gpg --homedir "$@" --recv-keys 8A9E14A07010F7E3

build: build/chaotic.elf

install: \
	$(foreach f, $(LIBS), $(DESTDIR)$(PREFIX)/lib/chaotic/${f}.sh) \
	$(foreach l, $(GUEST_ETC), $(DESTDIR)$(PREFIX)/lib/chaotic/guest/etc/${l}.conf) \
	$(foreach l, $(GUEST_BIN), $(DESTDIR)$(PREFIX)/lib/chaotic/guest/bin/${l}) \
	$(DESTDIR)$(PREFIX)/bin/chaotic.sh \
	$(DESTDIR)$(PREFIX)/bin/chaotic \
	$(DESTDIR)/var/lib/chaotic/interfere \
	$(DESTDIR)/var/cache/chaotic

.PHONY: install build
