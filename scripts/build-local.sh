#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

INSTALL_DIR="${HOME}/.local/bin"
INSTALL_PATH="${INSTALL_DIR}/omp"

echo "==> Building Oh My Pi locally..."

echo "==> Step 1: Building native addon..."
bun --cwd="${REPO_ROOT}" build:native

echo "==> Step 2: Building binary..."
bun --cwd="${REPO_ROOT}/packages/coding-agent" run build

echo "==> Step 3: Installing binary to ${INSTALL_PATH}..."
mkdir -p "${INSTALL_DIR}"
TMP_PATH="${INSTALL_PATH}.tmp.$$"
cp "${REPO_ROOT}/packages/coding-agent/dist/omp" "${TMP_PATH}"
chmod +x "${TMP_PATH}"
mv "${TMP_PATH}" "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"

echo "==> Verifying installation..."
INSTALLED_VERSION="$("${INSTALL_PATH}" --version)"
echo "==> Successfully installed omp ${INSTALLED_VERSION} to ${INSTALL_PATH}"

if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo "WARNING: ${INSTALL_DIR} is not in your PATH."
    echo "Add the following to your shell profile:"
    echo "    export PATH=\"${INSTALL_DIR}:\${PATH}\""
fi

echo "==> Done!"
