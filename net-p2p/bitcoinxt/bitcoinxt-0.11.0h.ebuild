# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit autotools bash-completion-r1 gnome2-utils systemd user xdg-utils

MY_PV="${PV/\.0h/H}"
DESCRIPTION="A full node Bitcoin Cash implementation with GUI, daemon and utils"
HOMEPAGE="https://bitcoinxt.software"
SRC_URI="https://github.com/${PN}/${PN}/archive/v${MY_PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~x86"
IUSE="daemon dbus +gui libressl +qrcode reduce-exports test upnp utils +wallet zeromq"
LANGS="ach af_ZA ar be_BY bg bs ca ca@valencia ca_ES cmn cs cy da de el_GR en
	eo es es_CL es_DO es_MX es_UY et eu_ES fa fa_IR fi fr fr_CA gl gu_IN he
	hi_IN hr hu id_ID it ja ka kk_KZ ko_KR ky la lt lv_LV mn ms_MY nb nl pam
	pl pt_BR pt_PT ro_RO ru sah sk sl_SI sq sr sv th_TH tr uk ur_PK uz@Cyrl
	vi vi_VN zh_HK zh_CN zh_TW"

for X in ${LANGS}; do
	IUSE="${IUSE} linguas_${X}"
done

CDEPEND="dev-libs/boost:0=[threads(+)]
	dev-libs/libevent
	net-misc/curl
	gui? (
		dev-libs/protobuf
		dev-qt/qtgui:5
		dev-qt/qtnetwork:5
		dev-qt/qtwidgets:5
		dbus? ( dev-qt/qtdbus:5 )
		qrcode? ( media-gfx/qrencode )
	)
	!libressl? ( dev-libs/openssl:0=[-bindist] )
	libressl? ( dev-libs/libressl:0= )
	upnp? ( net-libs/miniupnpc )
	wallet? ( sys-libs/db:4.8[cxx] )
	zeromq? ( net-libs/zeromq )"
DEPEND="${CDEPEND}
	gui? ( dev-qt/linguist-tools )"
RDEPEND="${CDEPEND}
	daemon? (
		!net-p2p/bitcoind
		!net-p2p/bitcoin-abc[daemon]
		!net-p2p/bitcoin-unlimited[daemon]
		!net-p2p/bucash[daemon]
	)
	gui?  (
		!net-p2p/bitcoin-qt
		!net-p2p/bitcoin-abc[gui]
		!net-p2p/bitcoin-unlimited[gui]
		!net-p2p/bucash[gui]
	)
	utils? (
		!net-p2p/bitcoin-cli
		!net-p2p/bitcoin-tx
		!net-p2p/bitcoin-abc[utils]
		!net-p2p/bitcoin-unlimited[utils]
		!net-p2p/bucash[utils]
	)"

REQUIRED_USE="dbus? ( gui ) qrcode? ( gui )"
RESTRICT="mirror"

DOCS=( doc/{assets-attribution,bips,tor}.md )

S="${WORKDIR}/${PN}-${MY_PV}"

pkg_setup() {
	if use daemon; then
		enewgroup bitcoinxt
		enewuser bitcoinxt -1 -1 /var/lib/bitcoinxt bitcoinxt
	fi
}

src_prepare() {
	if use gui; then
		# Fix compatibility with LibreSSL
		eapply "${FILESDIR}"/${PN}-0.11.0g-libressl.patch

		local filt= yeslang= nolang= lan ts x

		for lan in $LANGS; do
			if [ ! -e src/qt/locale/bitcoin_$lan.ts ]; then
				die "Language '$lan' no longer supported. Ebuild needs update."
			fi
		done

		for ts in $(ls src/qt/locale/*.ts)
		do
			x="${ts/*bitcoin_/}"
			x="${x/.ts/}"
			if ! use "linguas_$x"; then
				nolang="$nolang $x"
				rm "$ts" || die
				filt="$filt\\|$x"
			else
				yeslang="$yeslang $x"
			fi
		done
		filt="bitcoin_\\(${filt:2}\\)\\.\(qm\|ts\)"
		sed "/${filt}/d" -i 'src/qt/bitcoin_locale.qrc' || die
		sed "s/locale\/${filt}/bitcoin.qrc/" -i 'src/Makefile.qt.include' || die
		einfo "Languages -- Enabled:$yeslang -- Disabled:$nolang"
	fi

	use daemon || sed -i 's/have bitcoind &&//;s/^\(complete -F _bitcoind \)bitcoind \(bitcoin-cli\)$/\1\2/' \
		contrib/bitcoind.bash-completion || die

	use utils || sed -i 's/have bitcoind &&//;s/^\(complete -F _bitcoind bitcoind\) bitcoin-cli$/\1/' \
		contrib/bitcoind.bash-completion || die

	default
	eautoreconf
}

src_configure() {
	econf \
		--without-libs \
		--disable-bench \
		--disable-ccache \
		--disable-maintainer-mode \
		$(usex gui "--with-gui=qt5" --without-gui) \
		$(use_with daemon) \
		$(use_with qrcode qrencode) \
		$(use_with upnp miniupnpc) \
		$(use_with utils) \
		$(use_enable reduce-exports) \
		$(use_enable test tests) \
		$(use_enable wallet) \
		$(use_enable zeromq zmq) \
		|| die "econf failed"
}

src_install() {
	default

	if use daemon; then
		insinto /etc/bitcoinxt
		newins "${FILESDIR}"/${PN}.conf bitcoin.conf
		fowners bitcoinxt:bitcoinxt /etc/bitcoinxt/bitcoin.conf
		fperms 600 /etc/bitcoinxt/bitcoin.conf
		newins contrib/debian/examples/bitcoin.conf bitcoin.conf.example

		newinitd "${FILESDIR}"/${PN}.initd-r2 ${PN}
		newconfd "${FILESDIR}"/${PN}.confd-r2 ${PN}
		systemd_newunit "${FILESDIR}"/${PN}.service-r1 ${PN}.service
		systemd_newtmpfilesd "${FILESDIR}"/${PN}.tmpfilesd-r1 ${PN}.conf

		doman contrib/debian/manpages/{bitcoind.1,bitcoin.conf.5}
		newbashcomp contrib/bitcoind.bash-completion bitcoin

		insinto /etc/logrotate.d
		newins "${FILESDIR}"/${PN}.logrotate-r1 ${PN}
	fi

	if use gui; then
		local X
		for X in 16 32 64 128 256; do
			newicon -s ${X} "share/pixmaps/bitcoin${X}.png" bitcoin.png
		done
		make_desktop_entry "bitcoin-qt %u" "Bitcoin XT" "bitcoin" \
			"Qt;Network;P2P;Office;Finance;" "MimeType=x-scheme-handler/bitcoincash;\nTerminal=false"

		doman contrib/debian/manpages/bitcoin-qt.1
	fi

	if use utils; then
		doman contrib/debian/manpages/bitcoin-cli.1
		use daemon || newbashcomp contrib/bitcoind.bash-completion bitcoin
	fi
}

pkg_preinst() {
	use gui && gnome2_icon_savelist
}

update_caches() {
	gnome2_icon_cache_update
	xdg_desktop_database_update
}

pkg_postinst() {
	use gui && update_caches
}

pkg_postrm() {
	use gui && update_caches
}
