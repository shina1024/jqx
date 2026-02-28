#include "moonbit.h"

#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *jqx_copy_path(moonbit_bytes_t path, int path_len) {
  if (path_len < 0) {
    return NULL;
  }
  size_t n = (size_t)path_len;
  char *out = (char *)malloc(n + 1);
  if (out == NULL) {
    return NULL;
  }
  if (n > 0) {
    memcpy(out, path, n);
  }
  out[n] = '\0';
  return out;
}

MOONBIT_EXPORT int jqx_read_file_size_ffi(moonbit_bytes_t path, int path_len) {
  char *c_path = jqx_copy_path(path, path_len);
  if (c_path == NULL) {
    return -1;
  }
  FILE *fp = fopen(c_path, "rb");
  free(c_path);
  if (fp == NULL) {
    return -1;
  }
  if (fseek(fp, 0, SEEK_END) != 0) {
    fclose(fp);
    return -1;
  }
  long size = ftell(fp);
  fclose(fp);
  if (size < 0 || size > INT_MAX) {
    return -1;
  }
  return (int)size;
}

MOONBIT_EXPORT int jqx_read_file_into_ffi(moonbit_bytes_t path, int path_len,
                                          moonbit_bytes_t out, int out_len) {
  if (out_len < 0) {
    return -1;
  }
  char *c_path = jqx_copy_path(path, path_len);
  if (c_path == NULL) {
    return -1;
  }
  FILE *fp = fopen(c_path, "rb");
  free(c_path);
  if (fp == NULL) {
    return -1;
  }
  size_t want = (size_t)out_len;
  size_t got = fread(out, 1, want, fp);
  if (ferror(fp)) {
    fclose(fp);
    return -1;
  }
  int extra = fgetc(fp);
  fclose(fp);
  if (extra != EOF) {
    return -1;
  }
  if (got > (size_t)INT_MAX) {
    return -1;
  }
  return (int)got;
}
