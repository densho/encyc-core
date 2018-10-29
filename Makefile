PROJECT=encyc-core
APP=encyccore
USER=encyc
SHELL = /bin/bash

APP_VERSION := $(shell cat VERSION)
GIT_SOURCE_URL=https://github.com/densho/encyc-core

# Release name e.g. jessie
DEBIAN_CODENAME := $(shell lsb_release -sc)
# Release numbers e.g. 8.10
DEBIAN_RELEASE := $(shell lsb_release -sr)
# Sortable major version tag e.g. deb8
DEBIAN_RELEASE_TAG = deb$(shell lsb_release -sr | cut -c1)

# current branch name minus dashes or underscores
PACKAGE_BRANCH := $(shell git rev-parse --abbrev-ref HEAD | tr -d _ | tr -d -)
# current commit hash
PACKAGE_COMMIT := $(shell git log -1 --pretty="%h")
# current commit date minus dashes
PACKAGE_TIMESTAMP := $(shell git log -1 --pretty="%ad" --date=short | tr -d -)

PACKAGE_SERVER=ddr.densho.org/static/$(APP)

INSTALL_BASE=/opt
INSTALLDIR=$(INSTALL_BASE)/encyc-core
DOWNLOADS_DIR=/tmp/$(APP)-install
PIP_REQUIREMENTS=$(INSTALLDIR)/requirements.txt
PIP_CACHE_DIR=$(INSTALL_BASE)/pip-cache

VIRTUALENV=$(INSTALLDIR)/venv/encyccore

DEB_BRANCH := $(shell git rev-parse --abbrev-ref HEAD | tr -d _ | tr -d -)
DEB_ARCH=amd64
DEB_NAME_STRETCH=$(APP)-$(DEB_BRANCH)
# Application version, separator (~), Debian release tag e.g. deb8
# Release tag used because sortable and follows Debian project usage.
DEB_VERSION_STRETCH=$(APP_VERSION)~deb9
DEB_FILE_STRETCH=$(DEB_NAME_STRETCH)_$(DEB_VERSION_STRETCH)_$(DEB_ARCH).deb
DEB_VENDOR=Densho.org
DEB_MAINTAINER=<geoffrey.jost@densho.org>
DEB_DESCRIPTION=Encyclopedia publishing tools
DEB_BASE=opt/encyc-core

CONF_BASE=/etc/encyc

LOGS_BASE=/var/log/$(PROJECT)

.PHONY: help


help:
	@echo "encyc-core Install Helper"
	@echo ""
	@echo "get     - Downloads source, installers, and assets files. Does not install."
	@echo ""
	@echo "install - Installs app, config files, and static assets.  Does not download."
	@echo ""
	@echo "uninstall - Deletes 'compiled' Python files. Leaves build dirs and configs."
	@echo "clean   - Deletes files created by building the program. Leaves configs."
	@echo ""
	@echo "branch BRANCH=[branch] - Switches encyc-core and supporting repos to [branch]."
	@echo ""


get: get-app apt-update

install: install-prep install-app install-configs

uninstall: uninstall-app

clean: clean-app


install-prep: apt-upgrade install-core git-config install-misc-tools install-setuptools

apt-update:
	@echo ""
	@echo "Package update ---------------------------------------------------------"
	apt-get --assume-yes update

apt-upgrade:
	@echo ""
	@echo "Package upgrade --------------------------------------------------------"
	apt-get --assume-yes upgrade

install-core:
	apt-get --assume-yes install bzip2 curl gdebi-core logrotate ntp p7zip-full wget

git-config:
	git config --global alias.st status
	git config --global alias.co checkout
	git config --global alias.br branch
	git config --global alias.ci commit

install-misc-tools:
	@echo ""
	@echo "Installing miscellaneous tools -----------------------------------------"
	apt-get --assume-yes install ack-grep byobu elinks htop mg multitail

install-virtualenv:
	apt-get --assume-yes install python-pip python-virtualenv
	test -d $(VIRTUALENV) || virtualenv --distribute --setuptools $(VIRTUALENV)

install-setuptools: install-virtualenv
	@echo ""
	@echo "install-setuptools -----------------------------------------------------"
	apt-get --assume-yes install python-dev
	source $(VIRTUALENV)/bin/activate; \
	pip install -U bpython setuptools


get-app: get-encyc-core

install-app: install-setuptools install-encyc-core

uninstall-app: uninstall-encyc-core

clean-app: clean-encyc-core


get-encyc-core:
	git pull
	source $(VIRTUALENV)/bin/activate; \
	pip install --exists-action=i -r $(PIP_REQUIREMENTS)

setup-encyc-core: install-configs
	@echo ""
	@echo "setup encyc-core -----------------------------------------------------"
	cd $(INSTALLDIR)
	source $(VIRTUALENV)/bin/activate; \
	python setup.py install
# logs dir
	-mkdir $(LOGS_BASE)
	chown -R $(USER).root $(LOGS_BASE)
	chmod -R 755 $(LOGS_BASE)

install-encyc-core:
	@echo ""
	@echo "install encyc-core -----------------------------------------------------"
# bs4 dependency
	apt-get --assume-yes install libxml2 libxml2-dev libxslt1-dev rsync zlib1g-dev
	source $(VIRTUALENV)/bin/activate; \
	pip install -U --find-links=$(PIP_CACHE_DIR) -r $(PIP_REQUIREMENTS)
	cd $(INSTALLDIR)
	source $(VIRTUALENV)/bin/activate; \
	python setup.py install
# logs dir
	-mkdir $(LOGS_BASE)
	chown -R $(USER).root $(LOGS_BASE)
	chmod -R 755 $(LOGS_BASE)

uninstall-encyc-core:
	@echo ""
	@echo "uninstall encyc-core ------------------------------------------------------"
	cd $(INSTALLDIR)/encyc-core
	source $(VIRTUALENV)/bin/activate; \
	-pip uninstall -r $(PIP_REQUIREMENTS)
	-rm /usr/local/lib/python2.7/dist-packages/encyc-*
	-rm -Rf /usr/local/lib/python2.7/dist-packages/encyc

clean-encyc-core:
	-rm     $(INSTALLDIR)/encyc/*.pyc
	-rm -Rf $(INSTALLDIR)/encyc_core.egg-info/
	-rm -Rf $(INSTALLDIR)/build/
	-rm -Rf $(INSTALLDIR)/dist/
	-rm -Rf $(INSTALLDIR)/venv/
	-rm -Rf /usr/local/lib/python2.7/dist-packages/encyc*

clean-pip:
	-rm -Rf $(PIP_CACHE_DIR)/*


branch:
	cd $(INSTALLDIR)/encyc; python ./bin/git-checkout-branch.py $(BRANCH)


install-configs:
	@echo ""
	@echo "install configs ---------------------------------------------------------"
	-mkdir /etc/encyc
	cp $(INSTALLDIR)/conf/core.cfg /etc/encyc/
	chown root.encyc /etc/encyc/core.cfg
	chmod 644 /etc/encyc/core.cfg
	touch /etc/encyc/core-local.cfg
	chown root.encyc /etc/encyc/core-local.cfg
	chmod 640 /etc/encyc/core-local.cfg

uninstall-configs:


# http://fpm.readthedocs.io/en/latest/
# https://stackoverflow.com/questions/32094205/set-a-custom-install-directory-when-making-a-deb-package-with-fpm
# https://brejoc.com/tag/fpm/
deb: deb-stretch

# http://fpm.readthedocs.io/en/latest/
# https://stackoverflow.com/questions/32094205/set-a-custom-install-directory-when-making-a-deb-package-with-fpm
# https://brejoc.com/tag/fpm/
deb-stretch:
	@echo ""
	@echo "FPM packaging (stretch) ------------------------------------------------"
	-rm -Rf $(DEB_FILE_STRETCH)
	virtualenv --relocatable $(VIRTUALENV)  # Make venv relocatable
	fpm   \
	--verbose   \
	--input-type dir   \
	--output-type deb   \
	--name $(DEB_NAME_STRETCH)   \
	--version $(DEB_VERSION_STRETCH)   \
	--package $(DEB_FILE_STRETCH)   \
	--url "$(GIT_SOURCE_URL)"   \
	--vendor "$(DEB_VENDOR)"   \
	--maintainer "$(DEB_MAINTAINER)"   \
	--description "$(DEB_DESCRIPTION)"   \
	--chdir $(INSTALLDIR)   \
	--depends "rsync"   \
	.git=$(DEB_BASE)   \
	.gitignore=$(DEB_BASE)   \
	bin=$(DEB_BASE)   \
	conf=$(DEB_BASE)   \
	COPYRIGHT=$(DEB_BASE)   \
	encyc=$(DEB_BASE)   \
	INSTALL=$(DEB_BASE)   \
	LICENSE=$(DEB_BASE)   \
	Makefile=$(DEB_BASE)   \
	README.rst=$(DEB_BASE)   \
	requirements.txt=$(DEB_BASE)  \
	setup.py=$(DEB_BASE)  \
	setup.sh=$(DEB_BASE)  \
	VERSION=$(DEB_BASE)  \
	venv=$(DEB_BASE)   \
	conf/core.cfg=$(CONF_BASE)/core.cfg
