# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

EGO_VENDOR=( "github.com/jteeuwen/go-bindata a0ff256" )

inherit golang-vcs-snapshot systemd user

MY_PV="${PV/_/-}"
EGO_PN="github.com/containous/${PN}"
DESCRIPTION="A modern HTTP reverse proxy and load balancer made to deploy microservices"
HOMEPAGE="https://traefik.io"
SRC_URI="https://${EGO_PN}/releases/download/v${MY_PV}/${PN}-v${MY_PV}.src.tar.gz -> ${P}.tar.gz
	${EGO_VENDOR_URI}"
RESTRICT="mirror strip test"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="examples"

DOCS=( {CHANGELOG,CONTRIBUTING,README}.md )

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

pkg_setup() {
	enewgroup traefik
	enewuser traefik -1 -1 -1 traefik
}

src_compile() {
	export GOPATH="${G}"
	local PATH="${G}/bin:$PATH"
	local GOLDFLAGS="-s -w \
		-X ${EGO_PN}/version.Version=${MY_PV} \
		-X ${EGO_PN}/version.Codename=cheddar \
		-X '${EGO_PN}/version.BuildDate=$(date -u '+%Y-%m-%d_%I:%M:%S%p')'"

	ebegin "Building go-bindata locally"
	pushd vendor/github.com/jteeuwen/go-bindata > /dev/null || die
	go build -v -ldflags "-s -w" -o \
		"${G}"/bin/go-bindata ./go-bindata || die
	popd > /dev/null || die
	eend $?

	go generate || die
	go build -v -ldflags "${GOLDFLAGS}" \
		./cmd/traefik || die
}

# Broken :/
#src_test() {
#	go test -v ./... || die
#}

src_install() {
	dobin traefik
	einstalldocs

	newinitd "${FILESDIR}"/${PN}.initd ${PN}
	systemd_dounit "${FILESDIR}"/${PN}.service

	insinto /etc/traefik
	newins traefik.sample.toml traefik.toml.example

	if use examples; then
		docinto examples
		dodoc -r examples/*
		docompress -x /usr/share/doc/${PF}/examples
	fi

	diropts -o traefik -g traefik -m 0750
	dodir /var/log/traefik
}

pkg_postinst() {
	if [ ! -e "${EROOT%/}"/etc/${PN}/traefik.toml ]; then
		elog "No traefik.toml found, copying the example over"
		cp "${EROOT%/}"/etc/${PN}/traefik.toml{.example,} || die
	else
		elog "traefik.toml found, please check example file for possible changes"
	fi
}
