#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/jqlang/jq.git}"
UPSTREAM_REF="${UPSTREAM_REF:-master}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${DEST_DIR:-${REPO_ROOT}/third_party/jq-tests}"
TMP_DIR="$(mktemp -d -t jq-tests-sync-XXXXXX)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

git clone --depth 1 --branch "${UPSTREAM_REF}" "${UPSTREAM_REPO}" "${TMP_DIR}"
UPSTREAM_COMMIT="$(git -C "${TMP_DIR}" rev-parse HEAD | tr -d '\r')"
SYNCED_AT_UTC="$(date -u +%Y-%m-%d)"

FILES_TO_COPY=(
  "COPYING"
  "tests/base64.test"
  "tests/jq.test"
  "tests/man.test"
  "tests/manonig.test"
  "tests/onig.test"
  "tests/optional.test"
  "tests/uri.test"
  "tests/no-main-program.jq"
  "tests/yes-main-program.jq"
)

DIRS_TO_COPY=(
  "tests/modules"
)

rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"

for relative_file in "${FILES_TO_COPY[@]}"; do
  source_path="${TMP_DIR}/${relative_file}"
  target_path="${DEST_DIR}/${relative_file}"
  mkdir -p "$(dirname "${target_path}")"
  cp "${source_path}" "${target_path}"
done

for relative_dir in "${DIRS_TO_COPY[@]}"; do
  source_dir="${TMP_DIR}/${relative_dir}"
  target_dir="${DEST_DIR}/${relative_dir}"
  mkdir -p "$(dirname "${target_dir}")"
  cp -R "${source_dir}" "${target_dir}"
done

cat > "${DEST_DIR}/README.md" <<EOF
# jq upstream tests (vendored)

- upstream: ${UPSTREAM_REPO}
- ref: ${UPSTREAM_REF}
- commit: ${UPSTREAM_COMMIT}
- synced_at_utc: ${SYNCED_AT_UTC}

This directory is copied from \`jqlang/jq\` using \`scripts/update_jq_tests.ps1\`
or \`scripts/update_jq_tests.sh\`.
EOF

printf '%s\n' "${UPSTREAM_REPO}" > "${DEST_DIR}/UPSTREAM_REPO"
printf '%s\n' "${UPSTREAM_REF}" > "${DEST_DIR}/UPSTREAM_REF"
printf '%s\n' "${UPSTREAM_COMMIT}" > "${DEST_DIR}/UPSTREAM_COMMIT"

echo "Vendored jq tests to: ${DEST_DIR}"
echo "Upstream commit: ${UPSTREAM_COMMIT}"
