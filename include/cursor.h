#pragma once

#include <stddef.h>
#include <stdlib.h>

typedef struct Cursor Cursor;
struct Cursor {
    int ln;
    int ch;
    int ideal_ch;

    int x;
    int y;
};
