# Maintainer: Chad Voegele <cavoegele@gmail.com>

pkgname=s7
pkgver=1.0
pkgrel=1
pkgdesc="Sync directory to S3"
arch=(any)
url="https://github.com/chadvoegele/s7"
license=('MIT')
depends=(nodejs)
makedepends=(git)
options=(!strip)
source=("git+https://github.com/chadvoegele/s7.git")
md5sums=('SKIP')

package() {
  cd "$pkgname"
  install -Dm755 s7 "${pkgdir}/usr/bin/s7"
}
