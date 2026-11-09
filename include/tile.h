#pragma once

#include <stdio.h>

typedef struct Buf Buf;
typedef struct Cursor Cursor;
typedef struct Frame Frame;
typedef struct LBkCv LBkCv;
enum Mode : int;
typedef enum Mode Mode;
typedef struct Rect Rect;

typedef enum {
    buf_tt,
    bufs_tt,
} TileType;

typedef struct BkCv BkCv; // buffer key, cursor value
struct BkCv {
    Buf *k;
    Cursor v;
};

typedef struct Tile Tile;
struct Tile {
    Buf *buf;
    LBkCv *lBkCv;
    Cursor curs;
    Rect rect;
    TileType ttype;
};

Tile *initTile(Rect rect, Buf *buf);
void freeTile(Tile *tile);

void drawTileOnFrame(Tile *tile, Frame *frame, Mode mode);
void updateCursor(Tile *t);
