/*
  Permission to use, copy, modify, and/or distribute this software for
  any purpose with or without fee is hereby granted.

  THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL
  WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
  OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE
  FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
  AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
  OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/
#include "../cbalz.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char *buf_a = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\0";
char buf_b[2048] = {0};

int main(void) {
  balz_context ctx = NULL;
  const uint8_t *buf_out = NULL;
  int64_t num_out = -1;
  const char *error = NULL;

  fprintf(stderr, "Compressing string \"%s\"...\n", buf_a);

  ctx = balz_compress((const uint8_t *)buf_a, strlen(buf_a) + 1, true, &buf_out, &num_out, &error);
  if (error) {
    fprintf(stderr, "error: %s\n", error);
    exit(1);
  }
  assert(buf_out != NULL);
  assert(num_out <= sizeof(buf_b));
  assert(num_out >= 0);
  assert(buf_out[0] == 0xBA);

  memcpy(buf_b, buf_out, num_out);

  balz_free(ctx);
  buf_out = NULL;

  fprintf(stderr, "Decompressing data...\n");

  ctx = balz_decompress((const uint8_t *)buf_b, num_out, &buf_out, &num_out, &error);
  if (error) {
    fprintf(stderr, "error: %s\n", error);
    exit(1);
  }
  assert(buf_out != NULL);
  assert(num_out <= sizeof(buf_b));
  assert(num_out >= 0);

  memcpy(buf_b, buf_out, num_out);

  balz_free(ctx);

  if (!strncmp(buf_a, buf_b, sizeof(buf_b))) {
    fprintf(stderr, "Round-trip OK: %s\n", buf_b);
  } else {
    fprintf(stderr, "Round-trip NOK: %ld vs %ld\n", num_out, strlen(buf_a));
    exit(1);
  }
}
