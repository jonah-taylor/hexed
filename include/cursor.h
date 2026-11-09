#pragma once

#include <stddef.h>
#include <stdlib.h>

typedef struct Cursor Cursor;
struct Cursor {
    size_t ln;
    size_t ch;
    size_t ideal_ch;

    size_t x;
    size_t y;
};
