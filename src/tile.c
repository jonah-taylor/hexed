#include "tile.h"

#include "buf.h"
#include "cursor.h"
#include "frame.h"
#include "geometry.h"
#include "term.h"

#include "utils/xmem.h"

Tile*
initTile(Rect tmp_rect)
{
    Tile *tile;

    tile = xmalloc(sizeof(*tile));
    *tile = (Tile){
        .buf = initBuf("empty"),
        .cursor = initCursor(),
        .rect = xmalloc(sizeof(tmp_rect)),
        .ttype = buf_tt,
    };

    *tile->rect = tmp_rect;

    return tile;
}

void
freeTile(Tile *tile)
{
    freeBuf(tile->buf);
    free(tile->cursor);
    free(tile->rect);

    free(tile);
}

void
drawTileOnFrame(Tile *tile, Frame *frame)
{
    size_t i;
    size_t width, height;
    size_t x1, x2, y1, y2;

    x1 = fixedFromPercX(tile->rect->x1);
    x2 = fixedFromPercX(tile->rect->x2);
    y1 = fixedFromPercY(tile->rect->y1);
    y2 = fixedFromPercY(tile->rect->y2);

    width = x2 - x1;
    height = y2 - y1;
    for (i = 0; i <= width; i++) {
        setCell(frame, y1, x1 + i, (Cell){"#"});
        setCell(frame, y2, x1 + i, (Cell){"#"});
    }
    for (i = 0; i <= height; i++) {
        setCell(frame, y1 + i, x1, (Cell){"#"});
        setCell(frame, y1 + i, x2, (Cell){"#"});
    }
}

