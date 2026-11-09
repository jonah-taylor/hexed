#pragma once

#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static inline void*
xmalloc(int bytes)
{
    void *p;

    p = malloc(bytes);
    if (!p) {
        fprintf(stderr, "error: out of memory (malloc)");
        exit(1);
    }
    return p;
}

static inline void*
xcalloc(int bytes)
{
    void *p;

    p = calloc(bytes, 1);
    if (!p) {
        fprintf(stderr, "error: out of memory (calloc)");
        exit(1);
    }
    return p;
}

static inline void*
xrealloc(void *ptr, int *cap, int t_sz)
{
    void *p;

    if (*cap > INT_MAX / 2) {
        fprintf(stderr, "error: cap overflow (realloc)");
        exit(1);
    }

    *cap *= 2;

    if (*cap > INT_MAX / t_sz) {
        fprintf(stderr, "error: cap * t_sz overflow (realloc)");
        exit(1);
    }

    p = realloc(ptr, *cap * t_sz);
    if (!p) {
        fprintf(stderr, "error: out of memory (realloc)");
        exit(1);
    }
    return p;
}

static inline char*
xstrdup(const char *s)
{
    int len;
    void *copy;

    len = strlen(s);
    copy = xmalloc(len + 1);
    memcpy(copy, s, len);
    ((char *)copy)[len] = '\0';
    return copy;
}
