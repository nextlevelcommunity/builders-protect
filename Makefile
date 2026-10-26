APP_NAME := Builders Protect
DIST_APP := dist/$(APP_NAME).app
INSTALL_APP := $(HOME)/Applications/$(APP_NAME).app

.PHONY: build test test-cli test-all run install uninstall clean dmg

build:
	./scripts/build-app.sh release

test:
	swift test

test-cli:
	npm test

test-all: test test-cli

run: build
	open "$(DIST_APP)"

install: build
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(INSTALL_APP)"
	ditto "$(DIST_APP)" "$(INSTALL_APP)"
	@echo "Instalado em $(INSTALL_APP)"

uninstall:
	rm -rf "$(INSTALL_APP)"

clean:
	swift package clean
	rm -rf dist Resources/AppIcon.icns Resources/icon_1024x1024.png .build/AppIcon.iconset

dmg: build
	rm -rf dist/dmg-root
	mkdir -p dist/dmg-root
	ditto "$(DIST_APP)" "dist/dmg-root/$(APP_NAME).app"
	ln -s /Applications dist/dmg-root/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder dist/dmg-root -ov -format UDZO "dist/$(APP_NAME).dmg"
	rm -rf dist/dmg-root
	@echo "DMG em dist/$(APP_NAME).dmg"
