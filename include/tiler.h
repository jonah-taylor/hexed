#pragma once

#include <stddef.h>
#include "geometry.h"

typedef struct Tile Tile;

typedef struct Tiler Tiler;
struct Tiler
{
    Tile *tiles;
    size_t ts_len, ts_cap;
    size_t sel_idx;
};

void initTiler(Tiler *tiler);
void deinitTiler(Tiler *tiler);

Tile *getSel(Tiler *tiler);

void drawTiles(Tiler *tiler);
void newTile(Tiler *tiler, Dir dir);

void selTileInCursorDir(Tiler *tiler, Dir dir);
void rmTile(Tiler *tiler);
