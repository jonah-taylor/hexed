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
DEF_LIST(LBkCv, BkCv, lbkcv)

inline static void setTileCell(Rect *r, Frame *f, size_t *y, size_t *x, Cell c);
inline static size_t calcXPadN(long lns);
static void drawNumOnFrame(Tile *t, Frame *f, Mode m, size_t x, size_t y, size_t n);
static void drawLnOnFrame(Tile *t, Frame *f, size_t x, size_t y, size_t ln_i);
static void drawBufNameOnFrame(Tile *t, Frame *f, size_t x, size_t y);

Tile*
initTile(Rect rect, Buf *buf)
{
    Tile *tile;

    tile = xmalloc(sizeof(*tile));
    *tile = (Tile){
        .buf = buf,
        .curs = (Cursor){0},
        .lBkCv = initLBkCv(), // TODO
        .rect = rect,
        .ttype = buf_tt,
    };

    return tile;
}

void
freeTile(Tile *tile)
{
    freeLBkCv(tile->lBkCv);
    free(tile);
}

void
drawTileOnFrame(Tile *tile, Frame *frame, Mode mode)
{
    size_t ln_i;
    size_t x, y;
    Rect r;
    size_t xpadn;

    r = fixedFromPercRect(tile->rect);
    xpadn = calcXPadN(tile->buf->lns->len);

    y = 0;
    for (ln_i = 0; y < (r.y2 - r.y1) - 1; ln_i++) {
        x = xpadn;
        drawNumOnFrame(tile, frame, mode, y, x, (ln_i + 1));
        x = xpadn + 2;
        drawLnOnFrame(tile, frame, y, x, ln_i);
        y++;
    }

    x = (r.x2 - r.x1) - strlen(tile->buf->name) - 1 ;
    y = (r.y2 - r.y1) - 1;
    drawBufNameOnFrame(tile, frame, y, x);
}

inline static void
setTileCell(Rect *r, Frame *f, size_t *y, size_t *x, Cell c)
{
    if (*x >= (r->x2 - r->x1)) return;
    if (*y >= (r->y2 - r->y1)) return;

    setFrameCell(f, (r->y1 + *y), (r->x1 + *x), c);
}

static size_t
calcXPadN(long lns)
{
    size_t xpadn = 0;
    while (lns > 0) {
        lns /= 10;
        xpadn++;
    }
    xpadn--;
    return xpadn;
}

static void
drawLnOnFrame(Tile *t, Frame *f, size_t y, size_t x, size_t ln_i)
{
    size_t ch_i, xpadn;
    Rect r;
    LLCh *lns;
    char ch;

    r = fixedFromPercRect(t->rect);

    lns = t->buf->lns;
    xpadn = x;

    // draw each line char
    for (ch_i = 0; ch_i < lns->items[ln_i]->len; ch_i++) {

        ch = lns->items[ln_i]->items[ch_i];
        setTileCell(&r, f, &y, &x, (Cell){.str = {ch, '\0'}, .fg = -1});
        x++;

        // wrap at tile width
        if (r.x1 + x == r.x2 - 1) {
            x = xpadn;
            y++;
        }
    }
}

static void
drawNumOnFrame(Tile *t, Frame *f, Mode mode, size_t y, size_t x, size_t num)
{
    Rect r;
    char ch;

    r = fixedFromPercRect(t->rect);

    while (num > 0) {
        ch = ('0' + (num % 10));
        setTileCell(&r, f, &y, &x,
            (Cell){
                .str = {ch,'\0'},
                .fg = (mode == RESIZING) ? 1 : -1,
            });
        num /= 10;
        x--;
    }
}

static void
drawBufNameOnFrame(Tile *t, Frame *f, size_t y, size_t x)
{
    char ch, *str;
    size_t ch_i;
    Rect r;

    r = fixedFromPercRect(t->rect);

    // draw tile name
    str = t->buf->name;
    for (ch_i = 0; ch_i < strlen(str); ch_i++) {
        ch = str[ch_i];
        setTileCell(&r, f, &y, &x, (Cell){.str = {ch, '\0'}, .fg = -1});
        x++;
    }
}

