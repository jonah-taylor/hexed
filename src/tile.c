#include "app.h"
#include "buf.h"
#include "cursor.h"
#include "frame.h"
#include "geometry.h"
#include "term.h"
#include "tile.h"
#include "utils/list.h"
#include "utils/xmem.h"

DEF_LIST(LCh, char, lch)
DEF_LIST(LLCh, LCh*, llch)

Tile*
initTile(Rect tmp_rect, Buf *buf)
{
    Tile *tile;

    tile = xmalloc(sizeof(*tile));
    *tile = (Tile){
        .buf = buf,
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
    free(tile->cursor);
    free(tile->rect);

    free(tile);
}

void
drawTileOnFrame(Tile *tile, Frame *frame, Mode mode)
{
    size_t i, j;
    size_t width, height;
    size_t x1, x2, y1, y2;
    size_t x, y;
    size_t num, lnum_padn;
    LLCh *lns;
    char ch;

    x1 = fixedFromPercX(tile->rect->x1);
    x2 = fixedFromPercX(tile->rect->x2);
    y1 = fixedFromPercY(tile->rect->y1);
    y2 = fixedFromPercY(tile->rect->y2);

    width = x2 - x1;
    height = y2 - y1;

    lns = tile->buf->lns;

    num = lns->len;
    lnum_padn = 0;
    while (num > 0) {
        num /= 10;
        lnum_padn++;
    }

    y = 0;

    for (i = 0; i < lns->len; i++) {

        // draw line num
        x = lnum_padn;
        num = i + 1;
        while (num > 0) {
            ch = ('0' + (num % 10));
            setCell(frame, y1 + y, x1 + x, (Cell){{ch, '\0'}});
            num /= 10;
            x--;
        }

        // draw line
        x = lnum_padn + 2;
        for (j = 0; j < lns->items[i]->len; j++) {
            ch = lns->items[i]->items[j];
            setCell(frame, y1 + y, x1 + x, (Cell){{ch, '\0'}});
            x++;
        }

        y++;
    }


    // for (i = 0; i <= width; i++) {
    //     setCell(frame, y1, x1 + i, (Cell){"#"});
    //     setCell(frame, y2, x1 + i, (Cell){"#"});
    // }
    // for (i = 0; i <= height; i++) {
    //     setCell(frame, y1 + i, x1, (Cell){"#"});
    //     setCell(frame, y1 + i, x2, (Cell){"#"});
    // }
}

