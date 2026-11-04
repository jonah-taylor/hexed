#pragma once

#include <stdio.h>

typedef struct Buf Buf;
typedef struct Cursor Cursor;
typedef struct Rect Rect;

typedef enum {
    buf_tt,
    bufs_tt,
} TileType;

typedef struct Tile Tile;
struct Tile
{
    Buf *buf;
    Cursor *cursor;
    Rect *rect;
    TileType ttype;
};

Tile *initTile(Rect rect);
void freeTile(Tile *tile);

void drawTile(Tile *tile);
