#pragma once

#include "cursor.h"
#include "geometry.h"

typedef enum {
    text,
    buf_menu,
} TileType;

typedef struct Tile Tile;
struct Tile
{
    // Buffer *buf;
    Cursor cursor;
    Rect rect;
    TileType type;
};

void initTile(Tile *tile, Rect rect, Cursor cursor);
void deinitTile(Tile *tile);

void drawTile(Tile *tile);
