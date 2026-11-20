#pragma once

#include "xmem.h"

#include <stdio.h>
#include <string.h>

static inline int
writeToClipboard(char *str)
{
    FILE *f;
    f = popen("wl-copy", "w");
    if (!f) return 0;
    fwrite(str, 1, strlen(str), f);
    return pclose(f) == 0;
}

static inline int
readClipboardInto(char **str, int cap)
{
    FILE *f;
    char buf[2048];
    int i, n, len;

    f = popen("wl-paste --no-newline", "r");
    if (!f) return 0;

    len = 0;
    while ((n = fread(buf, 1, sizeof(buf), f)) > 0) {
        for (i = 0; i < n; i++) {
            if (len + 1 == cap)
                *str = xrealloc(*str, &cap, sizeof(char));
            (*str)[len++] = buf[i];
        }
    }
    pclose(f);

    return len;
}

