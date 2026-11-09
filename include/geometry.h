#pragma once

#include <stddef.h>

typedef struct Rect Rect;
struct Rect
{
    int x1, x2, y1, y2;
};

typedef struct Tab Tab;
struct Tab
{
    int rows, cols;
};

enum Dir : int {
    UP = 0,
    DOWN = 1,
    LEFT = 2,
    RIGHT = 3,
};
typedef enum Dir Dir;
