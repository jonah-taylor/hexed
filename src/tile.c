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

inline static void setTileCell(Rect *r, Frame *f, int *y, int *x, Cell c);
inline static size_t calcNumLen(size_t lns);
static void drawNumOnFrame(Tile *t, Frame *f, Mode m, int x, int y, size_t n);
static void drawLnOnFrame(Tile *t, Frame *f, int x, int y, size_t ln_i);
static void drawBufNameOnFrame(Tile *t, Frame *f, int x, int y);
static int calcLnHeight(Rect *r, size_t *ln_len, size_t *xpadn);

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
drawTileOnFrame(Tile *t, Frame *f, Mode m)
{
    int ln_i, x, y;
    Rect r;
    size_t xpadn;
    LLCh *lns;

    lns = t->buf->lns;
    r = fixedFromPercRect(t->rect);
    xpadn = calcNumLen(lns->len);

    // draw line at cursor
    y = (r.y2 - r.y1) / 2;
    ln_i = t->curs.ln;
    x = calcNumLen(ln_i + 1);
    drawNumOnFrame(t, f, m, y, x, (ln_i + 1));
    x = xpadn + 2;
    drawLnOnFrame(t, f, y, x, ln_i);

    // draw lines under cursor
    y = (r.y2 - r.y1) / 2;
    for (ln_i = t->curs.ln + 1; (size_t)ln_i < lns->len && y < (r.y2 - r.y1) - 1; ln_i++) {
        y += calcLnHeight(&r, &lns->items[ln_i - 1]->len, &xpadn);
        x = xpadn;
        drawNumOnFrame(t, f, m, y, x, (ln_i - t->curs.ln));
        x = xpadn + 2;
        drawLnOnFrame(t, f, y, x, ln_i);
    }
    // ~ filler
    y++;
    for (x = 0; y < r.y2 - 1; y++)
        setTileCell(&r, f, &y, &x, (Cell){.str = "~", .fg = 90});

    // draw lines above cursor
    y = (r.y2 - r.y1) / 2;
    for (ln_i = t->curs.ln - 1; ln_i >= 0 && y >= 0; ln_i--) {
        y -= calcLnHeight(&r, &lns->items[ln_i]->len, &xpadn);
        x = xpadn;
        drawNumOnFrame(t, f, m, y, x, (t->curs.ln - ln_i));
        x = xpadn + 2;
        drawLnOnFrame(t, f, y, x, ln_i);
    }

    // ~ filler
    y--;
    for (x = 0; y >= 0; y--)
        setTileCell(&r, f, &y, &x, (Cell){.str = "~", .fg = 90});

    x = (r.x2 - r.x1) - strlen(t->buf->name) - 1;
    y = (r.y2 - r.y1) - 1;
    drawBufNameOnFrame(t, f, y, x);
}

void
updateCursor(Tile *t)
{
    int x, y;
    int ln_len, ch_wid, y_off;
    Rect r;
    size_t xpadn;
    LLCh *lns;

    lns = t->buf->lns;
    r = fixedFromPercRect(t->rect);
    xpadn = calcNumLen(lns->len);
    ln_len = t->curs.ch + 1;

    y = (r.y2 - r.y1) / 2;
    ch_wid = ((r.x2 - 1) - r.x1 - (xpadn + 2));
    if (ln_len == 0 || ch_wid <= 0)
        y_off = 1;
    else
        y_off = ((ln_len + ch_wid - 1) / ch_wid);
    y += y_off;

    x = ln_len - (ch_wid * (y_off - 1));

    t->curs.y = y - 1;
    t->curs.x = (xpadn + 2) + x - 1;

    moveCursorTo(
        r.y1 + t->curs.y,
        r.x1 + t->curs.x
    );
}

inline static void
setTileCell(Rect *r, Frame *f, int *y, int *x, Cell c)
{
    if (*x < 0 || *x >= (r->x2 - r->x1) - 1) return;
    if (*y < 0 || *y >= (r->y2 - r->y1)) return;

    setFrameCell(f, (r->y1 + *y), (r->x1 + *x), c);
}

static size_t
calcNumLen(size_t lns)
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
drawLnOnFrame(Tile *t, Frame *f, int y, int x, size_t ln_i)
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
        if (ch == ' ')
            setTileCell(&r, f, &y, &x, (Cell){.str = {(char)0xC2, (char)0xB7, 0, 0}, .fg = 90});
        else
            setTileCell(&r, f, &y, &x, (Cell){.str = {ch, '\0'}});
        x++;

        // wrap at tile width
        if (r.x1 + x == r.x2 - 1) {
            x = xpadn;
            y++;
        }
    }
}

static void
drawNumOnFrame(Tile *t, Frame *f, Mode mode, int y, int x, size_t num)
{
    Rect r;
    char ch;

    r = fixedFromPercRect(t->rect);

    while (num > 0) {
        ch = ('0' + (num % 10));
        setTileCell(&r, f, &y, &x,
            (Cell){
                .str = {ch,'\0'},
                .fg = (mode == RESIZING) ? 31 : 0,
            });
        num /= 10;
        x--;
    }
}

static void
drawBufNameOnFrame(Tile *t, Frame *f, int y, int x)
{
    char ch, *str;
    size_t ch_i;
    Rect r;

    r = fixedFromPercRect(t->rect);

    // draw tile name
    str = t->buf->name;
    for (ch_i = 0; ch_i < strlen(str); ch_i++) {
        ch = str[ch_i];
        setTileCell(&r, f, &y, &x, (Cell){.str = {ch, '\0'}});
        x++;
    }
}

static int
calcLnHeight(Rect *r, size_t *ln_len, size_t *xpadn)
{
    int ch_wid;
    ch_wid = ((r->x2 - 1) - r->x1 - (*xpadn + 2));
    if (*ln_len == 0 || ch_wid <= 0)
        return 1;
    else
        return ((*ln_len + ch_wid - 1) / ch_wid);
}

