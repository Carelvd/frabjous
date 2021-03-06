# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

EGO_VENDOR=( "github.com/jteeuwen/go-bindata a0ff256" )

inherit golang-vcs-snapshot systemd user

PKG_COMMIT="b1100b5"
EGO_PN="github.com/gogits/gogs"
DESCRIPTION="A painless self-hosted Git service"
HOMEPAGE="https://gogs.io"
SRC_URI="https://${EGO_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	${EGO_VENDOR_URI}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cert memcached mysql openssh pam postgres redis sqlite tidb"

RDEPEND="dev-vcs/git[curl,threads]
	memcached? ( net-misc/memcached )
	mysql? ( virtual/mysql )
	openssh? ( net-misc/openssh )
	pam? ( virtual/pam )
	postgres? ( dev-db/postgresql )
	redis? ( dev-db/redis )
	sqlite? ( dev-db/sqlite )
	tidb? ( dev-db/tidb )"
RESTRICT="mirror strip"

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

pkg_setup() {
	enewgroup gogs
	enewuser gogs -1 /bin/bash /var/lib/gogs gogs
}

src_prepare() {
	local GOGS_PREFIX="${EPREFIX}/var/lib/gogs"

	sed -i \
		-e "s:^RUN_USER =.*:RUN_USER = gogs:" \
		-e "s:^ROOT =:ROOT = ${GOGS_PREFIX}/repos:" \
		-e "s:^TEMP_PATH =.*:TEMP_PATH = ${GOGS_PREFIX}/data/tmp/uploads:" \
		-e "s:^STATIC_ROOT_PATH =:STATIC_ROOT_PATH = ${EPREFIX}/usr/share/gogs:" \
		-e "s:^APP_DATA_PATH =.*:APP_DATA_PATH = ${GOGS_PREFIX}/data:" \
		-e "s:^PATH = data/gogs.db:PATH = ${GOGS_PREFIX}/data/gogs.db:" \
		-e "s:^PROVIDER_CONFIG =.*:PROVIDER_CONFIG = ${GOGS_PREFIX}/data/sessions:" \
		-e "s:^AVATAR_UPLOAD_PATH =.*:AVATAR_UPLOAD_PATH = ${GOGS_PREFIX}/data/avatars:" \
		-e "s:^PATH = data/attachments:PATH = ${GOGS_PREFIX}/data/attachments:" \
		-e "s:^ROOT_PATH =:ROOT_PATH = ${EPREFIX}/var/log/gogs:" \
		conf/app.ini || die

	sed -i "s:GitHash=.*:GitHash=${PKG_COMMIT}\":" \
		Makefile || die

	default
}

src_compile() {
	export GOPATH="${G}"
	local PATH="${G}/bin:$PATH" TAGS_OPTS=

	ebegin "Building go-bindata locally"
	pushd vendor/github.com/jteeuwen/go-bindata > /dev/null || die
	go build -v -ldflags "-s -w" -o \
		"${G}"/bin/go-bindata ./go-bindata || die
	popd > /dev/null || die
	eend $?

	use cert && TAGS_OPTS+=" cert"
	use pam && TAGS_OPTS+=" pam"
	use sqlite && TAGS_OPTS+=" sqlite"
	use tidb && TAGS_OPTS+=" tidb"

	LDFLAGS="-s -w" \
	TAGS="${TAGS_OPTS/ /}" \
	emake build
}

src_test() {
	go test -v -cover -race ./... || die
}

src_install() {
	dobin gogs

	newinitd "${FILESDIR}"/${PN}.initd-r2 ${PN}
	systemd_dounit "${FILESDIR}"/${PN}.service
	systemd_newtmpfilesd "${FILESDIR}"/${PN}.tmpfilesd-r1 ${PN}.conf

	insinto /var/lib/gogs/conf
	newins conf/app.ini app.ini.example

	insinto /usr/share/gogs
	doins -r {conf,templates}

	insinto /usr/share/gogs/public
	doins -r public/{assets,css,img,js,plugins}

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/${PN}.logrotate-r1 ${PN}

	diropts -m 0750
	dodir /var/lib/gogs/data /var/log/gogs
	fowners -R gogs:gogs /var/{lib,log}/gogs
}

pkg_postinst() {
	if [ ! -e "${EROOT%/}"/var/lib/gogs/conf/app.ini ]; then
		elog "No app.ini found, copying the example over"
		cp "${EROOT%/}"/var/lib/gogs/conf/app.ini{.example,} || die
	else
		elog "app.ini found, please check example file for possible changes"
	fi
}
