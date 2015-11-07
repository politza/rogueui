MOD_BASE_NAME = rogueui
MOD_VERSION = 0.1
MOD_NAME = $(MOD_BASE_NAME)-$(MOD_VERSION)

SCRIPTS = $(MOD_BASE_NAME).lua modinit.lua
DIST_DIR = dist

INVINC_INSTALL_DIR = $(HOME)/games/invisible

all: dist

dist: dist/$(MOD_NAME).tar.gz

dist/$(MOD_NAME).tar.gz: scripts.zip
	mkdir -p dist/game/dlc/$(MOD_BASE_NAME)
	mv scripts.zip dist/game/dlc/$(MOD_BASE_NAME)
	cp README.org dist/game/dlc/$(MOD_BASE_NAME)
	cd dist && tar czf $(MOD_NAME).tar.gz game

scripts.zip: $(SCRIPTS)
	zip -uq scripts.zip $(SCRIPTS) || [ $$? -eq 12 ] # no updates

clean:
	rm -rf -- $(DIST_DIR)
	rm -f  -- scripts.zip

install: dist/$(MOD_NAME).tar.gz
	[ -d "$(INVINC_INSTALL_DIR)/game" ]
	tar xzf dist/$(MOD_NAME).tar.gz -C "$(INVINC_INSTALL_DIR)"

uninstall:
	-rm -r -- "$(INVINC_INSTALL_DIR)/game/dlc/$(MOD_BASE_NAME)"

run: install
	cd $(INVINC_INSTALL_DIR)/game && ../start.sh |\
		grep -i '\[rogueui\]\|\<warning\>\|\<error\>\|:[0-9]\+:' |\
		sed -e 's/^[ \t]\(.*\.lua:[0-9]\+:.*\)/\1/'
