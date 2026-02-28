#include "moonbit.h"

#include <limits.h>
#include <locale.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static char *jqx_copy_pattern(moonbit_bytes_t pattern, int pattern_len) {
  if (pattern_len < 0) {
    return NULL;
  }
  size_t n = (size_t)pattern_len;
  char *out = (char *)malloc(n + 1);
  if (out == NULL) {
    return NULL;
  }
  if (n > 0) {
    memcpy(out, pattern, n);
  }
  out[n] = '\0';
  return out;
}

static void jqx_build_tm(struct tm *out, int year, int month, int day, int hour,
                         int minute, int second, int day_of_week,
                         int day_of_year) {
  memset(out, 0, sizeof(*out));
  out->tm_year = year - 1900;
  out->tm_mon = month - 1;
  out->tm_mday = day;
  out->tm_hour = hour;
  out->tm_min = minute;
  out->tm_sec = second;
  out->tm_wday = ((day_of_week % 7) + 7) % 7;
  out->tm_yday = day_of_year;
  out->tm_isdst = -1;
}

static int jqx_run_strftime(const char *pattern, int year, int month, int day,
                            int hour, int minute, int second, int day_of_week,
                            int day_of_year, char **out_text,
                            size_t *out_len) {
  if (pattern == NULL || out_text == NULL || out_len == NULL) {
    return -1;
  }

  (void)setlocale(LC_TIME, "");

  struct tm tmv;
  jqx_build_tm(&tmv, year, month, day, hour, minute, second, day_of_week,
               day_of_year);

  const size_t cap = 65536;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    return -1;
  }
  size_t n = strftime(buf, cap, pattern, &tmv);
  if (n == 0 && pattern[0] != '\0') {
    free(buf);
    return -1;
  }
  *out_text = buf;
  *out_len = n;
  return 0;
}

MOONBIT_EXPORT int jqx_strftime_size_ffi(moonbit_bytes_t pattern,
                                         int pattern_len, int year, int month,
                                         int day, int hour, int minute,
                                         int second, int day_of_week,
                                         int day_of_year) {
  char *c_pattern = jqx_copy_pattern(pattern, pattern_len);
  if (c_pattern == NULL) {
    return -1;
  }
  char *out = NULL;
  size_t n = 0;
  int rc = jqx_run_strftime(c_pattern, year, month, day, hour, minute, second,
                            day_of_week, day_of_year, &out, &n);
  free(c_pattern);
  if (rc != 0) {
    return -1;
  }
  free(out);
  if (n > (size_t)INT_MAX) {
    return -1;
  }
  return (int)n;
}

MOONBIT_EXPORT int jqx_strftime_into_ffi(
    moonbit_bytes_t pattern, int pattern_len, int year, int month, int day,
    int hour, int minute, int second, int day_of_week, int day_of_year,
    moonbit_bytes_t out, int out_len) {
  if (out_len < 0) {
    return -1;
  }

  char *c_pattern = jqx_copy_pattern(pattern, pattern_len);
  if (c_pattern == NULL) {
    return -1;
  }

  char *formatted = NULL;
  size_t n = 0;
  int rc = jqx_run_strftime(c_pattern, year, month, day, hour, minute, second,
                            day_of_week, day_of_year, &formatted, &n);
  free(c_pattern);
  if (rc != 0) {
    return -1;
  }
  if (n != (size_t)out_len) {
    free(formatted);
    return -1;
  }
  if (n > 0) {
    memcpy(out, formatted, n);
  }
  free(formatted);
  return out_len;
}
