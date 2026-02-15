#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CASES_PATH="${1:-${SCRIPT_DIR}/jq_compat_cases.json}"
JQ_BIN="${JQ_BIN:-jq}"
MOON_BIN="${MOON_BIN:-moon}"

resolve_jq_bin() {
  if command -v "${JQ_BIN}" >/dev/null 2>&1; then
    command -v "${JQ_BIN}"
    return 0
  fi

  if command -v mise >/dev/null 2>&1; then
    local candidate
    candidate="$(mise which jq 2>/dev/null | tr -d '\r')"
    if [[ -n "${candidate}" ]] && [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  if command -v mise.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
    local candidate_win candidate_unix
    candidate_win="$(mise.exe which jq 2>/dev/null | tr -d '\r')"
    if [[ -n "${candidate_win}" ]]; then
      candidate_unix="$(wslpath -u "${candidate_win}" 2>/dev/null || true)"
      if [[ -n "${candidate_unix}" ]] && [[ -x "${candidate_unix}" ]]; then
        printf '%s\n' "${candidate_unix}"
        return 0
      fi
    fi
  fi

  return 1
}

resolve_moon_bin() {
  if command -v "${MOON_BIN}" >/dev/null 2>&1; then
    command -v "${MOON_BIN}"
    return 0
  fi

  if command -v moon.exe >/dev/null 2>&1; then
    command -v moon.exe
    return 0
  fi

  return 1
}

normalize_error_message() {
  local text="$1"
  printf '%s' "${text}" | sed -E \
    -e 's/^jq: error( \(at <stdin>:[0-9:]+\))?:[[:space:]]*//' \
    -e 's/^jqx: error( \(at <stdin>:[0-9:]+\))?:[[:space:]]*//'
}

JQ_BIN_RESOLVED="$(resolve_jq_bin)" || {
  echo "jq binary not found: ${JQ_BIN} (also checked mise)" >&2
  exit 2
}

MOON_BIN_RESOLVED="$(resolve_moon_bin)" || {
  echo "moon command not found: ${MOON_BIN}" >&2
  exit 2
}

had_pager=0
saved_pager=""
if [[ -v PAGER ]]; then
  had_pager=1
  saved_pager="${PAGER}"
fi
restore_pager() {
  if [[ ${had_pager} -eq 1 ]]; then
    export PAGER="${saved_pager}"
  else
    unset PAGER || true
  fi
}
trap restore_pager EXIT
unset PAGER || true

if [[ ! -f "${CASES_PATH}" ]]; then
  echo "cases file not found: ${CASES_PATH}" >&2
  exit 2
fi

CASES_PATH_FOR_JQ="${CASES_PATH}"
if [[ "${JQ_BIN_RESOLVED}" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
  CASES_PATH_FOR_JQ="$(wslpath -w "${CASES_PATH}")"
fi

if ! "${JQ_BIN_RESOLVED}" -e 'type == "array" and all(.[]; has("name") and has("filter") and has("input"))' "${CASES_PATH_FOR_JQ}" >/dev/null; then
  echo "invalid cases file format: ${CASES_PATH}" >&2
  exit 2
fi

cd "${REPO_ROOT}"
if ! "${MOON_BIN_RESOLVED}" run --target native cmd -- "." "null" >/dev/null 2>&1; then
  echo "failed to warm up jqx command via moon run" >&2
  exit 2
fi

total=0
passed=0
failed=0
skipped=0

while IFS= read -r case_json; do
  total=$((total + 1))
  name="$("${JQ_BIN_RESOLVED}" -r '.name' <<<"${case_json}")"
  filter="$("${JQ_BIN_RESOLVED}" -r '.filter' <<<"${case_json}")"
  input="$("${JQ_BIN_RESOLVED}" -r '.input' <<<"${case_json}")"
  expect_error="$("${JQ_BIN_RESOLVED}" -r '(.expect_error // false) | tostring' <<<"${case_json}")"
  expect_error_mode="$("${JQ_BIN_RESOLVED}" -r '(.expect_error_mode // "strict") | tostring' <<<"${case_json}")"
  expect_status="$("${JQ_BIN_RESOLVED}" -r 'if has("expect_status") then (.expect_status | tostring) else "" end' <<<"${case_json}")"
  skip_reason="$("${JQ_BIN_RESOLVED}" -r 'if has("skip_reason") and .skip_reason != null then (.skip_reason | tostring) else "" end' <<<"${case_json}")"
  jqx_use_stdin="$("${JQ_BIN_RESOLVED}" -r '(.jqx_use_stdin // true) | tostring' <<<"${case_json}")"
  name="${name%$'\r'}"
  filter="${filter%$'\r'}"
  input="${input%$'\r'}"
  expect_error="${expect_error%$'\r'}"
  expect_error_mode="${expect_error_mode%$'\r'}"
  expect_status="${expect_status%$'\r'}"
  skip_reason="${skip_reason%$'\r'}"
  jqx_use_stdin="${jqx_use_stdin%$'\r'}"

  if [[ -n "${skip_reason}" ]]; then
    skipped=$((skipped + 1))
    printf '[SKIP] %s (%s)\n' "${name}" "${skip_reason}"
    continue
  fi

  mapfile -t jq_args < <("${JQ_BIN_RESOLVED}" -r '.jq_args // [] | .[]' <<<"${case_json}")
  mapfile -t jqx_args < <("${JQ_BIN_RESOLVED}" -r '.jqx_args // [] | .[]' <<<"${case_json}")
  for i in "${!jq_args[@]}"; do
    jq_args[$i]="${jq_args[$i]%$'\r'}"
  done
  for i in "${!jqx_args[@]}"; do
    jqx_args[$i]="${jqx_args[$i]%$'\r'}"
  done

  set +e
  jq_out="$(printf '%s' "${input}" | "${JQ_BIN_RESOLVED}" -c "${jq_args[@]}" "${filter}" 2>&1)"
  jq_status=$?
  if [[ "${jqx_use_stdin}" == "true" ]]; then
    jqx_out="$(printf '%s' "${input}" | "${MOON_BIN_RESOLVED}" run --target native cmd -- "${jqx_args[@]}" "${filter}" 2>&1)"
  else
    jqx_out="$("${MOON_BIN_RESOLVED}" run --target native cmd -- "${jqx_args[@]}" "${filter}" "${input}" 2>&1 </dev/null)"
  fi
  jqx_status=$?
  set -e

  jq_out="$(printf '%s' "${jq_out}" | tr -d '\r')"
  jqx_out="$(printf '%s\n' "${jqx_out}" | sed '/^Blocking waiting for file lock /d' | tr -d '\r')"

  ok=false
  if [[ "${expect_error}" == "true" ]]; then
    jq_msg="$(normalize_error_message "${jq_out}")"
    jqx_msg="$(normalize_error_message "${jqx_out}")"
    jq_has_error=false
    jqx_has_error=false
    if [[ ${jq_status} -ne 0 || "${jq_out}" == jq:\ error* ]]; then
      jq_has_error=true
    fi
    if [[ ${jqx_status} -ne 0 || "${jqx_out}" == jqx:\ error* ]]; then
      jqx_has_error=true
    fi
    if [[ "${expect_error_mode}" == "any" || "${expect_error_mode}" == "ignore_msg" ]]; then
      if [[ "${jq_has_error}" == "true" && "${jqx_has_error}" == "true" ]]; then
        ok=true
      fi
    else
      if [[ "${jq_has_error}" == "true" && "${jqx_has_error}" == "true" && "${jq_msg}" == "${jqx_msg}" ]]; then
        ok=true
      fi
    fi
  elif [[ -n "${expect_status}" ]]; then
    if [[ ${jq_status} -eq ${expect_status} && ${jqx_status} -eq ${expect_status} && "${jq_out}" == "${jqx_out}" ]]; then
      ok=true
    fi
  else
    if [[ ${jq_status} -eq 0 && ${jqx_status} -eq 0 && "${jq_out}" == "${jqx_out}" ]]; then
      ok=true
    elif [[ ${jq_status} -ne 0 ]]; then
      jq_msg="$(normalize_error_message "${jq_out}")"
      jqx_msg="$(normalize_error_message "${jqx_out}")"
      jqx_has_error=false
      if [[ ${jqx_status} -ne 0 || "${jqx_out}" == jqx:\ error* ]]; then
        jqx_has_error=true
      fi
      if [[ "${jqx_has_error}" == "true" && "${jq_msg}" == "${jqx_msg}" ]]; then
        ok=true
      fi
    fi
  fi

  if [[ "${ok}" == "true" ]]; then
    passed=$((passed + 1))
    printf '[PASS] %s\n' "${name}"
  else
    failed=$((failed + 1))
    printf '[FAIL] %s\n' "${name}"
    printf '  filter: %s\n' "${filter}"
    printf '  input: %s\n' "${input}"
    if [[ "${expect_error}" == "true" ]]; then
      printf '  expect_error_mode=%s\n' "${expect_error_mode}"
    fi
    printf '  jq status=%s output=%s\n' "${jq_status}" "${jq_out}"
    printf '  jqx status=%s output=%s\n' "${jqx_status}" "${jqx_out}"
  fi
done < <("${JQ_BIN_RESOLVED}" -c '.[]' "${CASES_PATH_FOR_JQ}")

printf '\nSummary: total=%s passed=%s failed=%s skipped=%s\n' "${total}" "${passed}" "${failed}" "${skipped}"
if [[ ${failed} -ne 0 ]]; then
  exit 1
fi
