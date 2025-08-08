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
#pragma once

#ifndef __CBALZ_H_INCLUDED__
#define __CBALZ_H_INCLUDED__

#ifndef CBALZ_API
#define CBALZ_API
#endif

#ifdef __cplusplus
#include <cstdint>
#include <cstddef>

extern "C" {
#else // __cplusplus
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#endif // __cplusplus

typedef struct cbalz_context *balz_context;

CBALZ_API balz_context
balz_compress(const uint8_t *in_buf, uint64_t num_in, bool max, const uint8_t **out_buf, int64_t *num_out, const char **error);

CBALZ_API balz_context
balz_decompress(const uint8_t *in_buf, uint64_t num_in, const uint8_t **out_buf, int64_t *num_out, const char **error);

CBALZ_API void
balz_free(balz_context context);

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // __CBALZ_H_INCLUDED__
