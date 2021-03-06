# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

# Note: Keep EGO_VENDOR in sync with ./vendor/*
EGO_VENDOR=(
	"github.com/bifurcation/mint 8c88abf"
	"github.com/bmizerany/assert b7ed37b"
	"github.com/boltdb/bolt fa5367d"
	"github.com/chzyer/readline 6a4bc7b"
	"github.com/didip/tollbooth d6884c7"
	"github.com/dlclark/regexp2 7632a26"
	"github.com/dop251/goja 0aeff75"
	"github.com/eknkc/amber cdade1c"
	"github.com/fatih/color 5df930a"
	"github.com/flosch/pongo2 1f4be1e"
	"github.com/fsnotify/fsnotify 4da3e2c"
	"github.com/garyburd/redigo 34a326d"
	"github.com/getwe/figlet4go bc87934"
	"github.com/go-sql-driver/mysql fade210"
	"github.com/hashicorp/golang-lru 0a025b7"
	"github.com/juju/errors c7d06af"
	"github.com/juju/ratelimit 5b9ff86"
	"github.com/jvatic/goja-babel 00569a2"
	"github.com/kr/pretty cfb55aa"
	"github.com/kr/text 7cafcd8"
	"github.com/lib/pq b609790"
	"github.com/lucas-clemente/fnv128a 393af48"
	"github.com/lucas-clemente/quic-go-certificates d2f8652"
	"github.com/mattetti/filebuffer 3a1e8e5"
	"github.com/mattn/go-runewidth 97311d9"
	"github.com/mitchellh/go-homedir b8bc1bf"
	"github.com/mitchellh/mapstructure 06020f8"
	"github.com/natefinch/pie 9a0d720"
	"github.com/nsf/termbox-go 10cefba"
	"github.com/russross/blackfriday 6d1ef89"
	"github.com/shurcooL/sanitized_anchor_name 86672fc"
	"github.com/sirupsen/logrus 89742ae"
	"github.com/tylerb/graceful d72b015"
	"github.com/wellington/sass cab90b3"
	"github.com/xyproto/aes12 7578cf3"
	"github.com/xyproto/cookie 8ce3def"
	"github.com/xyproto/datablock f8aac43"
	"github.com/xyproto/jpath c3c5db5"
	"github.com/xyproto/mime baf4ad2"
	"github.com/xyproto/permissionbolt f88aff2"
	"github.com/xyproto/permissions2 9be57ce"
	"github.com/xyproto/permissionsql aade2a8"
	"github.com/xyproto/pinterface 05fa0e3"
	"github.com/xyproto/pstore f2fb098"
	"github.com/xyproto/quic-go 14d96d9"
	"github.com/xyproto/recwatch aaa94ab"
	"github.com/xyproto/simplebolt 01ad65c"
	"github.com/xyproto/simplehstore 363dad8"
	"github.com/xyproto/simplemaria 014c7f7"
	"github.com/xyproto/simpleredis a429173"
	"github.com/xyproto/term 9e12074"
	"github.com/xyproto/unzip 8239505"
	"github.com/yosssi/gcss 3967759"
	"github.com/yuin/gluamapper d836955"
	"github.com/yuin/gopher-lua eb1c729"
	"golang.org/x/crypto 2509b14 github.com/golang/crypto"
	"golang.org/x/net c73622c github.com/golang/net"
	"golang.org/x/sys 30ef8ff github.com/golang/sys"
	"golang.org/x/text 6eab0e8 github.com/golang/text"
	"gopkg.in/gcfg.v1 298b7a6 github.com/go-gcfg/gcfg"
	"gopkg.in/warnings.v0 8a33156 github.com/go-warnings/warnings"
)

inherit golang-vcs-snapshot systemd user

EGO_PN="github.com/xyproto/${PN}"
DESCRIPTION="Pure Go web server with built-in Lua, Markdown, HyperApp and Pongo2 support"
HOMEPAGE="http://algernon.roboticoverlords.org"
SRC_URI="https://${EGO_PN}/archive/${PV}.tar.gz -> ${P}.tar.gz
	${EGO_VENDOR_URI}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="examples mysql postgres redis"

RDEPEND="mysql? ( virtual/mysql )
	postgres? ( dev-db/postgresql:* )
	redis? ( dev-db/redis )"
RESTRICT="mirror strip"

DOCS=( Changelog.md )

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

pkg_setup() {
	enewgroup algernon
	enewuser algernon -1 -1 -1 algernon
}

src_compile() {
	export GOPATH="${G}"
	go build -v -ldflags "-s -w" || die
}

src_test() {
	go test -v ./... || die
}

src_install() {
	dobin {algernon,desktop/mdview}
	einstalldocs

	newinitd "${FILESDIR}"/${PN}.initd-r1 ${PN}
	newconfd "${FILESDIR}"/${PN}.confd-r1 ${PN}
	systemd_dounit "${FILESDIR}"/${PN}.service

	insinto /etc/algernon
	doins system/serverconf.lua

	if use examples; then
		docinto examples
		dodoc -r samples/*
		docompress -x /usr/share/doc/${PF}/examples
	fi

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/${PN}.logrotate ${PN}

	dodir /var/www/algernon
	diropts -o algernon -g algernon -m 0700
	dodir /var/log/algernon
}
