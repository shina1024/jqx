#include "moonbit.h"

#include <limits.h>
#include <locale.h>
#include <time.h>

MOONBIT_FFI_EXPORT int32_t jqx_strftime_with_epoch(
  int64_t epoch_seconds,
  moonbit_bytes_t format_ptr,
  moonbit_bytes_t out_ptr,
  int32_t out_len,
  int32_t use_localtime
) {
  static int locale_initialized = 0;

  if (format_ptr == NULL || out_ptr == NULL || out_len <= 0) {
    return 0;
  }
  if (!locale_initialized) {
    setlocale(LC_ALL, "");
    locale_initialized = 1;
  }

  time_t t = (time_t)epoch_seconds;
  struct tm tm_buf;
  struct tm* tm_ptr = NULL;

#if defined(_WIN32) || defined(_WIN64)
  errno_t err = use_localtime ? localtime_s(&tm_buf, &t) : gmtime_s(&tm_buf, &t);
  if (err != 0) {
    return 0;
  }
  tm_ptr = &tm_buf;
#else
  if (use_localtime) {
    if (localtime_r(&t, &tm_buf) == NULL) {
      return 0;
    }
  } else {
    if (gmtime_r(&t, &tm_buf) == NULL) {
      return 0;
    }
  }
  tm_ptr = &tm_buf;
#endif

  size_t written = strftime(
    (char*)out_ptr,
    (size_t)out_len,
    (const char*)format_ptr,
    tm_ptr
  );
  if (written == 0 || written > (size_t)INT32_MAX) {
    return 0;
  }
  return (int32_t)written;
}
