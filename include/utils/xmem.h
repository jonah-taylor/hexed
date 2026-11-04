#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static inline void*
xmalloc(size_t size)
{
    void *p;

    p = malloc(size);
    if (!p) {
        fprintf(stderr, "error: out of memory (malloc)");
        exit(1);
    }
    return p;
}

static inline void*
xrealloc(void *ptr, size_t size)
{
    void *p;

    p = realloc(ptr, size);
    if (!p) {
        fprintf(stderr, "error: out of memory (realloc)");
        exit(1);
    }
    return p;
}

static inline char*
xstrdup(const char *s)
{
    size_t len;
    void *copy;

    len = strlen(s);
    copy = xmalloc(len + 1);
    memcpy(copy, s, len);
    ((char *)copy)[len] = '\0';
    return copy;
}
