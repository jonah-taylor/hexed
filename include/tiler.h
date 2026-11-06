#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>

enum Dir : int;
typedef enum Dir Dir;
typedef struct Frame Frame;
typedef struct Tile Tile;

typedef struct Tiler Tiler;
struct Tiler
{
    Tile **tiles;
    size_t ts_len, ts_cap;
    size_t sel_idx;
};

Tiler *initTiler();
void freeTilerItems(Tiler *tiler);

Tile *getSel(Tiler *tiler);

void drawTilesOnFrame(Tiler *tiler, Frame *frame);
void newTile(Tiler *tiler, Dir dir);

void selTileInCursorDir(Tiler *tiler, Dir dir);
void swapCursorDir(Tiler *tiler, Dir);

void rmSel(Tiler *tiler);
void reszSel(Tiler *tiler, Dir dir, bool growing);
void rotTilesCW(Tiler *tiler);
