#pragma once

#include <stddef.h>

typedef struct Rect Rect;
struct Rect
{
    size_t x1, x2, y1, y2;
};

typedef struct Tab Tab;
struct Tab
{
    size_t rows, cols;
};

typedef enum {
    UP = 0,
    DOWN = 1,
    LEFT = 2,
    RIGHT = 3,
} Dir;
