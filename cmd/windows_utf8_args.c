#include "moonbit.h"

#include <stdint.h>
#include <stdio.h>

MOONBIT_FFI_EXPORT int32_t jqx_write_stdout(
  moonbit_bytes_t bytes,
  int32_t len
) {
  if (bytes == NULL || len < 0) {
    return -1;
  }
  size_t written = fwrite(bytes, 1, (size_t)len, stdout);
  return written == (size_t)len ? len : -1;
}

MOONBIT_FFI_EXPORT int32_t jqx_write_stderr(
  moonbit_bytes_t bytes,
  int32_t len
) {
  if (bytes == NULL || len < 0) {
    return -1;
  }
  size_t written = fwrite(bytes, 1, (size_t)len, stderr);
  if (written != (size_t)len || fputc('\n', stderr) == EOF) {
    return -1;
  }
  return fflush(stderr) == 0 ? len : -1;
}

#if defined(_WIN32) || defined(_WIN64)
#include <windows.h>
#include <shellapi.h>
#pragma comment(lib, "shell32.lib")
// jq-compatible parsing and paths are bounded at 10,000 levels. Reserve enough
// stack for the Windows native runtime to reach that explicit guard.
#pragma comment(linker, "/STACK:16777216")

static int32_t jqx_windows_utf8_arg_len_internal(
  int32_t index,
  char* out_ptr,
  int32_t out_len
) {
  int argc = 0;
  LPWSTR* argv_w = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv_w == NULL) {
    return -1;
  }
  if (index < 0 || index >= argc) {
    LocalFree(argv_w);
    return -1;
  }

  int needed = WideCharToMultiByte(
    CP_UTF8,
    0,
    argv_w[index],
    -1,
    NULL,
    0,
    NULL,
    NULL
  );
  if (needed <= 0) {
    LocalFree(argv_w);
    return -1;
  }

  int32_t len = (int32_t)needed - 1;
  if (out_ptr != NULL) {
    if (out_len <= len) {
      LocalFree(argv_w);
      return -1;
    }
    int written = WideCharToMultiByte(
      CP_UTF8,
      0,
      argv_w[index],
      -1,
      out_ptr,
      out_len,
      NULL,
      NULL
    );
    if (written <= 0) {
      LocalFree(argv_w);
      return -1;
    }
    out_ptr[len] = '\0';
  }
  LocalFree(argv_w);
  return len;
}

MOONBIT_FFI_EXPORT int32_t jqx_windows_utf8_argc(void) {
  int argc = 0;
  LPWSTR* argv_w = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv_w == NULL) {
    return -1;
  }
  LocalFree(argv_w);
  return (int32_t)argc;
}

MOONBIT_FFI_EXPORT int32_t jqx_windows_utf8_arg_len(int32_t index) {
  return jqx_windows_utf8_arg_len_internal(index, NULL, 0);
}

MOONBIT_FFI_EXPORT int32_t jqx_windows_utf8_arg_copy(
  int32_t index,
  moonbit_bytes_t out_ptr,
  int32_t out_len
) {
  if (out_ptr == NULL || out_len <= 0) {
    return -1;
  }
  return jqx_windows_utf8_arg_len_internal(index, (char*)out_ptr, out_len);
}

#else

MOONBIT_FFI_EXPORT int32_t jqx_windows_utf8_argc(void) {
  return -1;
}

MOONBIT_FFI_EXPORT int32_t jqx_windows_utf8_arg_len(int32_t index) {
  (void)index;
  return -1;
}

MOONBIT_FFI_EXPORT int32_t jqx_windows_utf8_arg_copy(
  int32_t index,
  moonbit_bytes_t out_ptr,
  int32_t out_len
) {
  (void)index;
  (void)out_ptr;
  (void)out_len;
  return -1;
}

#endif
