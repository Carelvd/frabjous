# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit golang-vcs-snapshot systemd user

GIT_COMMIT="9f5f4b2"
EGO_PN="github.com/${PN/-//}"
DESCRIPTION="Handles alerts sent by client applications such as the Prometheus"
HOMEPAGE="https://prometheus.io"
SRC_URI="https://${EGO_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"

RESTRICT="mirror strip"

pkg_setup() {
	if use test; then
		has network-sandbox $FEATURES && \
			die "The test phase require 'network-sandbox' to be disabled in FEATURES"
	fi

	enewgroup prometheus
	enewuser prometheus -1 -1 /var/lib/prometheus prometheus
}

src_compile() {
	local GOLDFLAGS="-s -w \
		-X ${EGO_PN}/vendor/${EGO_PN%/*}/common/version.Version=${PV} \
		-X ${EGO_PN}/vendor/${EGO_PN%/*}/common/version.Revision=${GIT_COMMIT} \
		-X ${EGO_PN}/vendor/${EGO_PN%/*}/common/version.BuildUser=$(id -un)@$(hostname -f) \
		-X ${EGO_PN}/vendor/${EGO_PN%/*}/common/version.Branch=non-git \
		-X ${EGO_PN}/vendor/${EGO_PN%/*}/common/version.BuildDate=$(date -u '+%Y%m%d-%I:%M:%S')"

	GOPATH="${S}" go install -v -ldflags "${GOLDFLAGS}" \
		${EGO_PN}/cmd/{alertmanager,amtool} || die
}

src_test() {
	export GOPATH="${S}"
	local PKGS=( $(go list ./... | grep -v -E '/vendor/|/ui|/test') )
	go test -short ${PKGS[@]} || die
}

src_install() {
	dobin bin/{alertmanager,amtool}

	newinitd "${FILESDIR}"/${PN}.initd ${PN}
	newconfd "${FILESDIR}"/${PN}.confd ${PN}
	systemd_dounit "${FILESDIR}"/${PN}.service

	pushd src/${EGO_PN} > /dev/null || die
	insinto /etc/alertmanager
	newins doc/examples/simple.yml alertmanager.yml.simple

	dodoc {NOTICE,{CHANGELOG,README}.md}
	popd > /dev/null || die

	diropts -o prometheus -g prometheus -m 0750
	dodir /var/{lib,log}/prometheus
	dodir /var/lib/prometheus/alertmanager
}