#!/usr/bin/env make
ifeq ($(PREFIX),)
    PREFIX := /usr/local
endif

LIBS = \
	db-bump \
	cleanup \
	deploy \
	interfere \
	lower-prepare \
	makepkg-gen-bash \
	makepkg-run-nspawn \
	queue-run-nspawn \
	sync	
GUEST_ETC = pacman makepkg
GUEST_BIN = internal-makepkg x11-wrapper

dir_guard=@install -dm755 "$(@D)"

$(DESTDIR)$(PREFIX)/bin/chaotic: src/chaotic
	$(dir_guard)
	install -m755 $< $@

$(DESTDIR)$(PREFIX)/lib/chaotic/%.sh: src/lib/%.sh
	$(dir_guard)
	install -m755 $< $@

$(DESTDIR)$(PREFIX)/lib/chaotic/guest/etc/%.conf: guest/etc/%.conf
	$(dir_guard)
	install -m644 $< $@

$(DESTDIR)$(PREFIX)/lib/chaotic/guest/bin/%: guest/bin/%
	$(dir_guard)
	install -m755 $< $@

/var/lib/chaotic/interfere:
	$(dir_guard)
	cd "$(@D)" && git clone 'https://github.com/chaotic-aur/interfere.git' interfere

install: \
	$(foreach f, $(LIBS), $(DESTDIR)$(PREFIX)/lib/chaotic/${f}.sh) \
	$(foreach l, $(GUEST_ETC), $(DESTDIR)$(PREFIX)/lib/chaotic/guest/etc/${l}.conf) \
	$(foreach l, $(GUEST_BIN), $(DESTDIR)$(PREFIX)/lib/chaotic/guest/bin/${l}) \
	$(DESTDIR)$(PREFIX)/bin/chaotic \
	/var/lib/chaotic/interfere

.PHONY: install