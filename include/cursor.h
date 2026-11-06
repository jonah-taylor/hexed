#pragma once

#include <stddef.h>
#include <stdlib.h>

typedef struct Cursor Cursor;
struct Cursor {
    size_t x, y;
};

Cursor* initCursor();
