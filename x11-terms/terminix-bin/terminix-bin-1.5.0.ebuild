# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6
RESTRICT="mirror"

inherit eutils

DESCRIPTION="A tiling terminal emulator for Linux using GTK+ 3"
HOMEPAGE="https://gnunn1.github.io/terminix-web/"
SRC_URI="https://github.com/gnunn1/terminix/releases/download/${PV}/terminix.zip -> ${P}.zip"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="gnome-keyring nautilus"

RDEPEND="nautilus? ( dev-python/nautilus-python )
	gnome-keyring? (
		app-crypt/libsecret
		gnome-base/gnome-keyring
	)"

S=${WORKDIR}

src_install() {
	insinto /usr
	doins -r usr/share || die

	into /usr
	dobin usr/bin/terminix || die
}

pkg_postinst() {
	glib-compile-schemas /usr/share/glib-2.0/schemas/
}
