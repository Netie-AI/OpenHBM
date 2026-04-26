#!/usr/bin/env bash
# Install OSS CAD Suite 2026-04-02 into /opt/oss-cad-suite.
# Idempotent -- skips download if the directory already exists.
set -euo pipefail

VERSION="${OSS_CAD_SUITE_VERSION:-2026-04-02}"
INSTALL_DIR="${OSS_CAD_SUITE_HOME:-/opt/oss-cad-suite}"
ARCH="$(uname -m)"

case "${ARCH}" in
  x86_64)  TARBALL_ARCH="linux-x64" ;;
  aarch64) TARBALL_ARCH="linux-arm64" ;;
  *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

if [[ -d "${INSTALL_DIR}" && -x "${INSTALL_DIR}/bin/yosys" ]]; then
  echo "OSS CAD Suite already installed at ${INSTALL_DIR}, skipping."
  exit 0
fi

VERSION_NODASH="${VERSION//-/}"
TARBALL="oss-cad-suite-${TARBALL_ARCH}-${VERSION_NODASH}.tgz"
URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${VERSION}/${TARBALL}"

apt-get update
apt-get install -y --no-install-recommends \
  build-essential ca-certificates curl git make \
  python3 python3-venv python3-pip pipx \
  libtinfo6 zlib1g libffi8 \
  ngspice xschem magic klayout \
  iverilog gtkwave \
  graphviz mscgen \
  ;

mkdir -p /tmp/oss-cad-suite-dl
pushd /tmp/oss-cad-suite-dl >/dev/null
echo "Downloading ${URL} ..."
curl -fL --retry 5 -o "${TARBALL}" "${URL}"
mkdir -p "$(dirname "${INSTALL_DIR}")"
tar -xzf "${TARBALL}" -C "$(dirname "${INSTALL_DIR}")"
# OSS CAD Suite extracts to ./oss-cad-suite/, normalise that to INSTALL_DIR.
if [[ -d "$(dirname "${INSTALL_DIR}")/oss-cad-suite" && \
      "$(dirname "${INSTALL_DIR}")/oss-cad-suite" != "${INSTALL_DIR}" ]]; then
  mv "$(dirname "${INSTALL_DIR}")/oss-cad-suite" "${INSTALL_DIR}"
fi
popd >/dev/null
rm -rf /tmp/oss-cad-suite-dl

echo "Installed OSS CAD Suite ${VERSION} -> ${INSTALL_DIR}"
"${INSTALL_DIR}/bin/yosys" -V | head -n 1
"${INSTALL_DIR}/bin/verilator" --version | head -n 1
