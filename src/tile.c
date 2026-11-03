#include "tile.h"
#include "term.h"
#include "geometry.h"
#include <stdio.h>

void
initTile(Tile *tile, Rect rect, Cursor cursor)
{
    *tile = (Tile){
        .cursor = cursor,
        .rect = rect,
        .type = text,
    };
}

void
deinitTile(Tile *tile)
{
    tile = tile;
    return;
}

void
drawTile(Tile *tile)
{
    size_t i;
    size_t width, height;
    size_t x1, x2, y1, y2;

    x1 = fixedFromPercX(tile->rect.x1);
    x2 = fixedFromPercX(tile->rect.x2);
    y1 = fixedFromPercY(tile->rect.y1);
    y2 = fixedFromPercY(tile->rect.y2);

    width = x2 - x1;
    height = y2 - y1;
    for (i = 0; i < width; i++) {
        drawStrAtLoc(y1, x1 + i, "#");
        drawStrAtLoc(y2, x1 + i, "#");
    }
    for (i = 0; i < height; i++) {
        drawStrAtLoc(y1 + i, x1, "#");
        drawStrAtLoc(y1 + i, x2, "#");
    }
}

