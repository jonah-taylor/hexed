#pragma once

#include <ctype.h>
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

void typeChar(Tile *t, char ch);
void typeEnter(Tile *t);

void rmLn(Tile *t);
void rmLnBeforeCurs(Tile *t);
void rmLnAfterCurs(Tile *t);
void rmLnBelow(Tile *t);
void rmLnAbove(Tile *t);

void typeBksp(Tile *t);
void typeTab(Tile *t);

void mvLeft(Tile *t);
void mvDown(Tile *t);
void mvUp(Tile *t);
void mvRight(Tile *t);

void jmpDown(Tile *t, int x);
void jmpUp(Tile *t, int x);

void newLnBelow(Tile *t);
void newLnAbove(Tile *t);

void mvFastLeft(Tile *t);
void mvFullLeft(Tile *t);

void mvFastRight(Tile *t);
void mvFullRight(Tile *t);

void rmNextCh(Tile *t);

void unindentLnFront(Tile *t);
void indentLnFront(Tile *t);
