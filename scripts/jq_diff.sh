#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CASES_PATH="${1:-${SCRIPT_DIR}/jq_compat_cases.json}"
JQ_BIN="${JQ_BIN:-jq}"
MOON_BIN="${MOON_BIN:-moon}"
JQX_RUNNER="${JQX_RUNNER:-native}"
JQX_BIN="${JQX_BIN:-}"
JQX_PROFILE="${JQX_PROFILE:-release}"
JQX_PROFILE_LOWER="$(printf '%s' "${JQX_PROFILE}" | tr '[:upper:]' '[:lower:]')"

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

resolve_jqx_bin() {
  if [[ -n "${JQX_BIN}" ]]; then
    if [[ -x "${JQX_BIN}" ]]; then
      printf '%s\n' "${JQX_BIN}"
      return 0
    fi
    return 1
  fi

  local candidates=()
  if [[ "${JQX_PROFILE_LOWER}" == "release" ]]; then
    candidates=(
      "${REPO_ROOT}/_build/native/release/build/cmd/cmd"
      "${REPO_ROOT}/_build/native/release/build/cmd/cmd.exe"
      "${REPO_ROOT}/_build/native/debug/build/cmd/cmd"
      "${REPO_ROOT}/_build/native/debug/build/cmd/cmd.exe"
    )
  else
    candidates=(
      "${REPO_ROOT}/_build/native/debug/build/cmd/cmd"
      "${REPO_ROOT}/_build/native/debug/build/cmd/cmd.exe"
      "${REPO_ROOT}/_build/native/release/build/cmd/cmd"
      "${REPO_ROOT}/_build/native/release/build/cmd/cmd.exe"
    )
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

normalize_error_message() {
  local text="$1"
  printf '%s' "${text}" | sed -E \
    -e '/^jqx?:[[:space:]]*[0-9]+[[:space:]]+compile error(s)?$/d' \
    -e 's/^jq: error( \(at <stdin>:[0-9:]+\))?:[[:space:]]*//' \
    -e 's/^jqx: error( \(at <stdin>:[0-9:]+\))?:[[:space:]]*//'
}

is_compiler_summary_line() {
  local line="$1"
  [[ "${line}" =~ ^jqx?:[[:space:]]*[0-9]+[[:space:]]+compile[[:space:]]+error(s)?$ ]]
}

join_lines() {
  if [[ $# -eq 0 ]]; then
    printf ''
    return
  fi

  printf '%s' "$1"
  shift

  local line
  for line in "$@"; do
    printf '\n%s' "${line}"
  done
}

classify_output() {
  local text="$1"
  local -a value_lines=()
  local -a debug_lines=()
  local -a error_lines=()

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if is_compiler_summary_line "${line}"; then
      continue
    fi
    if [[ "${line}" == \[\"DEBUG:\",* ]]; then
      debug_lines+=("${line}")
      continue
    fi
    if [[ "${line}" == jq:\ error* || "${line}" == jqx:\ error* ]]; then
      error_lines+=("$(normalize_error_message "${line}")")
      continue
    fi
    value_lines+=("${line}")
  done <<< "${text}"

  if [[ ${#value_lines[@]} -eq 0 ]]; then
    CLASS_VALUE=""
  else
    CLASS_VALUE="$(join_lines "${value_lines[@]}")"
  fi

  if [[ ${#debug_lines[@]} -eq 0 ]]; then
    CLASS_DEBUG=""
  else
    CLASS_DEBUG="$(join_lines "${debug_lines[@]}")"
  fi

  if [[ ${#error_lines[@]} -eq 0 ]]; then
    CLASS_ERROR=""
  else
    CLASS_ERROR="$(join_lines "${error_lines[@]}")"
  fi
}

JQ_BIN_RESOLVED="$(resolve_jq_bin)" || {
  echo "jq binary not found: ${JQ_BIN} (also checked mise)" >&2
  exit 2
}

MOON_BIN_RESOLVED="$(resolve_moon_bin)" || {
  echo "moon command not found: ${MOON_BIN}" >&2
  exit 2
}

if [[ "${JQX_RUNNER}" != "moon-run" && "${JQX_RUNNER}" != "native" ]]; then
  echo "invalid JQX_RUNNER: ${JQX_RUNNER} (expected moon-run or native)" >&2
  exit 2
fi

if [[ "${JQX_PROFILE_LOWER}" != "debug" && "${JQX_PROFILE_LOWER}" != "release" ]]; then
  echo "invalid JQX_PROFILE: ${JQX_PROFILE} (expected debug or release)" >&2
  exit 2
fi

had_pager=0
saved_pager=""
if [[ -n "${PAGER+x}" ]]; then
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
JQX_BIN_RESOLVED=""
if [[ "${JQX_RUNNER}" == "native" ]]; then
  build_cmd=("${MOON_BIN_RESOLVED}" build --target native)
  if [[ "${JQX_PROFILE_LOWER}" == "release" ]]; then
    build_cmd+=(--release)
  fi
  build_cmd+=(cmd)

  if ! "${build_cmd[@]}" >/dev/null 2>&1; then
    echo "failed to build native jqx executable" >&2
    exit 2
  fi

  JQX_BIN_RESOLVED="$(resolve_jqx_bin)" || {
    echo "jqx native executable not found under _build/native/{release,debug}/build/cmd" >&2
    exit 2
  }

  if ! "${JQX_BIN_RESOLVED}" "." "null" >/dev/null 2>&1; then
    echo "failed to warm up jqx native executable" >&2
    exit 2
  fi
else
  if ! "${MOON_BIN_RESOLVED}" run --target native cmd -- "." "null" >/dev/null 2>&1; then
    echo "failed to warm up jqx command via moon run" >&2
    exit 2
  fi
fi

total=0
passed=0
failed=0
skipped=0
temporary=0

while IFS= read -r case_json; do
  total=$((total + 1))
  name="$("${JQ_BIN_RESOLVED}" -r '.name' <<<"${case_json}")"
  filter="$("${JQ_BIN_RESOLVED}" -r '.filter' <<<"${case_json}")"
  input="$("${JQ_BIN_RESOLVED}" -r '.input' <<<"${case_json}")"
  expect_error="$("${JQ_BIN_RESOLVED}" -r '(.expect_error // false) | tostring' <<<"${case_json}")"
  expect_error_mode="$("${JQ_BIN_RESOLVED}" -r '(.expect_error_mode // "strict") | tostring' <<<"${case_json}")"
  source_kind="$("${JQ_BIN_RESOLVED}" -r '(.source_kind // "") | tostring' <<<"${case_json}")"
  expect_status="$("${JQ_BIN_RESOLVED}" -r 'if has("expect_status") then (.expect_status | tostring) else "" end' <<<"${case_json}")"
  skip_reason="$("${JQ_BIN_RESOLVED}" -r 'if has("skip_reason") and .skip_reason != null then (.skip_reason | tostring) else "" end' <<<"${case_json}")"
  compat_status="$("${JQ_BIN_RESOLVED}" -r '(.compat_status // "pass") | tostring' <<<"${case_json}")"
  compat_ledger_id="$("${JQ_BIN_RESOLVED}" -r 'if has("compat_ledger_id") and .compat_ledger_id != null then (.compat_ledger_id | tostring) else "" end' <<<"${case_json}")"
  compat_reason="$("${JQ_BIN_RESOLVED}" -r 'if has("compat_reason") and .compat_reason != null then (.compat_reason | tostring) else "" end' <<<"${case_json}")"
  compat_removal_condition="$("${JQ_BIN_RESOLVED}" -r 'if has("compat_removal_condition") and .compat_removal_condition != null then (.compat_removal_condition | tostring) else "" end' <<<"${case_json}")"
  jqx_use_stdin="$("${JQ_BIN_RESOLVED}" -r '(.jqx_use_stdin // true) | tostring' <<<"${case_json}")"
  name="${name%$'\r'}"
  filter="${filter%$'\r'}"
  input="${input%$'\r'}"
  expect_error="${expect_error%$'\r'}"
  expect_error_mode="${expect_error_mode%$'\r'}"
  source_kind="${source_kind%$'\r'}"
  expect_status="${expect_status%$'\r'}"
  skip_reason="${skip_reason%$'\r'}"
  compat_status="${compat_status%$'\r'}"
  compat_ledger_id="${compat_ledger_id%$'\r'}"
  compat_reason="${compat_reason%$'\r'}"
  compat_removal_condition="${compat_removal_condition%$'\r'}"
  jqx_use_stdin="${jqx_use_stdin%$'\r'}"

  if [[ "${compat_status}" != "pass" && "${compat_status}" != "temporary_exception" ]]; then
    echo "invalid compat_status for case ${name}: ${compat_status}" >&2
    exit 2
  fi
  if [[ "${compat_status}" == "temporary_exception" ]]; then
    if [[ -z "${compat_ledger_id}" || -z "${compat_reason}" || -z "${compat_removal_condition}" ]]; then
      echo "temporary_exception case ${name} must set compat_ledger_id, compat_reason, and compat_removal_condition" >&2
      exit 2
    fi
  fi

  if [[ -n "${skip_reason}" ]]; then
    skipped=$((skipped + 1))
    printf '[SKIP] %s (%s)\n' "${name}" "${skip_reason}"
    continue
  fi

  jq_args=()
  while IFS= read -r arg; do
    jq_args+=("${arg%$'\r'}")
  done < <("${JQ_BIN_RESOLVED}" -r '.jq_args // [] | .[]' <<<"${case_json}")

  jqx_args=()
  while IFS= read -r arg; do
    jqx_args+=("${arg%$'\r'}")
  done < <("${JQ_BIN_RESOLVED}" -r '.jqx_args // [] | .[]' <<<"${case_json}")

  set +e
  if [[ ${#jq_args[@]} -gt 0 ]]; then
    jq_out="$(printf '%s' "${input}" | "${JQ_BIN_RESOLVED}" -c "${jq_args[@]}" "${filter}" 2>&1)"
  else
    jq_out="$(printf '%s' "${input}" | "${JQ_BIN_RESOLVED}" -c "${filter}" 2>&1)"
  fi
  jq_status=$?

  if [[ "${JQX_RUNNER}" == "native" ]]; then
    if [[ "${jqx_use_stdin}" == "true" ]]; then
      if [[ ${#jqx_args[@]} -gt 0 ]]; then
        jqx_out="$(printf '%s' "${input}" | "${JQX_BIN_RESOLVED}" "${jqx_args[@]}" "${filter}" 2>&1)"
      else
        jqx_out="$(printf '%s' "${input}" | "${JQX_BIN_RESOLVED}" "${filter}" 2>&1)"
      fi
    else
      if [[ ${#jqx_args[@]} -gt 0 ]]; then
        jqx_out="$("${JQX_BIN_RESOLVED}" "${jqx_args[@]}" "${filter}" "${input}" 2>&1 </dev/null)"
      else
        jqx_out="$("${JQX_BIN_RESOLVED}" "${filter}" "${input}" 2>&1 </dev/null)"
      fi
    fi
  elif [[ "${jqx_use_stdin}" == "true" ]]; then
    if [[ ${#jqx_args[@]} -gt 0 ]]; then
      jqx_out="$(printf '%s' "${input}" | "${MOON_BIN_RESOLVED}" run --target native cmd -- "${jqx_args[@]}" "${filter}" 2>&1)"
    else
      jqx_out="$(printf '%s' "${input}" | "${MOON_BIN_RESOLVED}" run --target native cmd -- "${filter}" 2>&1)"
    fi
  else
    if [[ ${#jqx_args[@]} -gt 0 ]]; then
      jqx_out="$("${MOON_BIN_RESOLVED}" run --target native cmd -- "${jqx_args[@]}" "${filter}" "${input}" 2>&1 </dev/null)"
    else
      jqx_out="$("${MOON_BIN_RESOLVED}" run --target native cmd -- "${filter}" "${input}" 2>&1 </dev/null)"
    fi
  fi
  jqx_status=$?
  set -e

  jq_out="$(printf '%s' "${jq_out}" | tr -d '\r')"
  jqx_out="$(printf '%s\n' "${jqx_out}" | sed '/^Blocking waiting for file lock /d' | tr -d '\r')"
  classify_output "${jq_out}"
  jq_value_text="${CLASS_VALUE}"
  jq_debug_text="${CLASS_DEBUG}"
  jq_error_text="${CLASS_ERROR}"
  classify_output "${jqx_out}"
  jqx_value_text="${CLASS_VALUE}"
  jqx_debug_text="${CLASS_DEBUG}"
  jqx_error_text="${CLASS_ERROR}"

  ok=false
  if [[ "${expect_error}" == "true" ]]; then
    jq_msg="${jq_error_text}"
    jqx_msg="${jqx_error_text}"
    jq_has_error=false
    jqx_has_error=false
    if [[ ${jq_status} -ne 0 || -n "${jq_error_text}" ]]; then
      jq_has_error=true
    fi
    if [[ ${jqx_status} -ne 0 || -n "${jqx_error_text}" ]]; then
      jqx_has_error=true
    fi
    if [[ "${expect_error_mode}" == "any" || "${expect_error_mode}" == "ignore_msg" ]]; then
      if [[ "${source_kind}" == "compile_fail" ]]; then
        if [[ "${jq_has_error}" == "true" && "${jqx_has_error}" == "true" ]]; then
          ok=true
        fi
      else
        if [[ "${jq_has_error}" == "true" && "${jqx_has_error}" == "true" \
          && "${jq_value_text}" == "${jqx_value_text}" \
          && "${jq_debug_text}" == "${jqx_debug_text}" ]]; then
          ok=true
        fi
      fi
    else
      if [[ "${source_kind}" == "compile_fail" ]]; then
        if [[ "${jq_has_error}" == "true" && "${jqx_has_error}" == "true" \
          && "${jq_msg}" == "${jqx_msg}" ]]; then
          ok=true
        fi
      else
        if [[ "${jq_has_error}" == "true" && "${jqx_has_error}" == "true" \
          && "${jq_msg}" == "${jqx_msg}" \
          && "${jq_value_text}" == "${jqx_value_text}" \
          && "${jq_debug_text}" == "${jqx_debug_text}" ]]; then
          ok=true
        fi
      fi
    fi
  elif [[ -n "${expect_status}" ]]; then
    if [[ ${jq_status} -eq ${expect_status} && ${jqx_status} -eq ${expect_status} \
      && "${jq_value_text}" == "${jqx_value_text}" \
      && "${jq_debug_text}" == "${jqx_debug_text}" \
      && "${jq_error_text}" == "${jqx_error_text}" ]]; then
      ok=true
    fi
  else
    if [[ ${jq_status} -eq 0 && ${jqx_status} -eq 0 \
      && "${jq_value_text}" == "${jqx_value_text}" \
      && "${jq_debug_text}" == "${jqx_debug_text}" \
      && "${jq_error_text}" == "${jqx_error_text}" ]]; then
      ok=true
    elif [[ ${jq_status} -ne 0 ]]; then
      jq_msg="${jq_error_text}"
      jqx_msg="${jqx_error_text}"
      jqx_has_error=false
      if [[ ${jqx_status} -ne 0 || -n "${jqx_error_text}" ]]; then
        jqx_has_error=true
      fi
      if [[ "${jqx_has_error}" == "true" && "${jq_msg}" == "${jqx_msg}" \
        && "${jq_value_text}" == "${jqx_value_text}" \
        && "${jq_debug_text}" == "${jqx_debug_text}" ]]; then
        ok=true
      fi
    fi
  fi

  if [[ "${compat_status}" == "temporary_exception" ]]; then
    if [[ "${ok}" == "true" ]]; then
      failed=$((failed + 1))
      printf '[FAIL] %s\n' "${name}"
      printf '  documented temporary exception no longer reproduces: %s\n' "${compat_ledger_id}"
      printf '  removal_condition: %s\n' "${compat_removal_condition}"
      continue
    fi

    temporary=$((temporary + 1))
    printf '[TEMP] %s (%s)\n' "${name}" "${compat_ledger_id}"
    printf '  reason: %s\n' "${compat_reason}"
    printf '  removal_condition: %s\n' "${compat_removal_condition}"
    continue
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

printf '\nSummary: total=%s passed=%s temporary=%s failed=%s skipped=%s\n' "${total}" "${passed}" "${temporary}" "${failed}" "${skipped}"
if [[ ${failed} -ne 0 ]]; then
  exit 1
fi
