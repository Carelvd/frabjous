# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit systemd

EGO_PN="cypherpunks.ru/govpn"
EGO_LDFLAGS="-X cypherpunks.ru/govpn.Version=${PV}"

DESCRIPTION="A VPN daemon aimed to be reviewable, secure and DPI/censorship-resistant"
HOMEPAGE="http://www.govpn.info"
SRC_URI="http://www.govpn.info/download/${P}.tar.xz"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64 ~x86"

DEPEND=">=dev-lang/go-1.8"

src_compile() {
	GOPATH="${S}" go install -v -ldflags "${EGO_LDFLAGS}" \
		${EGO_PN}/cmd/${PN}-{client,server,verifier} || die
}

src_install() {
	dobin bin/${PN}-{client,server,verifier}
	newbin utils/newclient.sh ${PN}-newclient

	# ToDo: OpenRC's initscript

	newconfd "${FILESDIR}"/${PN}.confd ${PN}
	systemd_newuserunit "${FILESDIR}"/${PN}.service ${PN}@.service
	systemd_dounit "${FILESDIR}"/${PN}.target

	dodoc {AUTHORS,NEWS,README,THANKS}
	docinto html
	dodoc -r doc/${PN}.html/*
}