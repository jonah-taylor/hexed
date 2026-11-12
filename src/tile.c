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

static void roundCursInBounds(Tile *t);
inline static void setTileCell(Rect *r, Frame *f, int *y, int *x, Cell c);
inline static int calcNumLen(int lns);
static void drawNumOnFrame(Tile *t, Frame *f, Mode m, int x, int y, int n);
static void drawLnOnFrame(Tile *t, Frame *f, int x, int y, int ln_i);
static void drawBufNameOnFrame(Tile *t, Frame *f, int x, int y);
static int calcLnHeight(Rect *r, int *ln_len, int *xpadn);

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
    int xpadn;
    Rect r;
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
    for (ln_i = t->curs.ln + 1; ln_i < lns->len && y < (r.y2 - r.y1) - 1; ln_i++) {
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
    int xpadn;
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

void
typeChar(Tile *t, char ch)
{
    LCh *ln;

    ln = t->buf->lns->items[t->curs.ln];

    lchIns(ln, t->curs.ch, ch);
    t->curs.ch++;
    t->curs.ideal_ch = t->curs.ch;
}

void
rmLn(Tile *t)
{
    LLCh *lns;
    LCh *ln;

    lns = t->buf->lns;
    ln = lns->items[t->curs.ln];

    if (t->curs.ln == 0 && ln->len == 1) {
        ln->len = 0;
        t->curs.ch = 0;
        return;
    }

    freeLCh(lns->items[t->curs.ln]);
    llchRm(lns, t->curs.ln);

    t->curs.ch = t->curs.ideal_ch;
    roundCursInBounds(t);
}

void
rmLnBeforeCurs(Tile *t)
{
    while (t->curs.ch != 0)
        typeBksp(t);
}

void
rmLnAfterCurs(Tile *t)
{
    LCh *ln;
    ln = t->buf->lns->items[t->curs.ln];
    while (t->curs.ch != ln->len)
        rmNextCh(t);
}

void
rmLnBelow(Tile *t)
{
    LLCh *lns;
    lns = t->buf->lns;
    if (t->curs.ln == lns->len - 1)
        return;

    mvDown(t);
    rmLn(t);
    mvUp(t);
}

void
rmLnAbove(Tile *t)
{
    if (t->curs.ln == 0)
        return;

    mvUp(t);
    rmLn(t);
}

void
typeEnter(Tile *t)
{
    LLCh *lns;
    LCh *ln, *nln;
    lns = t->buf->lns;

    llchIns(lns, t->curs.ln + 1, initLCh());
    ln = lns->items[t->curs.ln];
    nln = lns->items[t->curs.ln + 1];

    lchResz(nln, ln->len - t->curs.ch);
    memmove(nln->items, (ln->items + t->curs.ch), nln->len);
    ln->len = t->curs.ch;

    t->curs.ln++;
    t->curs.ch = 0;
}

void
typeBksp(Tile *t)
{
    LLCh *lns;
    LCh *ln, *pln;

    if (t->curs.ch == 0 && t->curs.ln == 0)
        return;

    lns = t->buf->lns;
    ln = lns->items[t->curs.ln];

    if (t->curs.ln > 0)
        pln = lns->items[t->curs.ln - 1];

    if (t->curs.ch == 0 && t->curs.ln > 0) {
        t->curs.ch = pln->len;
        t->curs.ln--;
        t->curs.ideal_ch = t->curs.ch;
        lchResz(pln, pln->len + ln->len);
        memmove((pln->items + t->curs.ch), ln->items, ln->len);
        freeLCh(lns->items[t->curs.ln + 1]);
        llchRm(lns, t->curs.ln + 1);
        return;
    }

    if (t->curs.ch > 3
        && strncmp(ln->items + t->curs.ch - 4, "    ", 4) == 0) {
        lchRm(ln, t->curs.ch - 1);
        t->curs.ch--;
        while (t->curs.ch % 4 != 0) {
            lchRm(ln, t->curs.ch - 1);
            t->curs.ch--;
        }
        return;
    }

    lchRm(ln, t->curs.ch - 1);
    t->curs.ch--;
}

void
typeTab(Tile *t)
{
    LCh *ln;

    ln = t->buf->lns->items[t->curs.ln];
    do {
        lchIns(ln, t->curs.ch, ' ');
        t->curs.ch++;
    } while (t->curs.ch % 4 != 0);
}

void
unindentLnFront(Tile *t)
{
    int i;
    LCh *ln;

    ln = t->buf->lns->items[t->curs.ln];

    for (i = 0; i < 4; i++) {
        if (ln->items[0] != ' ')
            break;
        lchRm(ln, 0);
    }
}

void
indentLnFront(Tile *t)
{

    int i;
    LCh *ln;

    ln = t->buf->lns->items[t->curs.ln];

    for (i = 0; i < 4; i++)
        lchIns(ln, 0, ' ');
}

void
mvLeft(Tile *t)
{
    t->curs.ch--;
    roundCursInBounds(t);
    t->curs.ideal_ch = t->curs.ch;
}

void
mvDown(Tile *t)
{
    t->curs.ln++;
    t->curs.ch = t->curs.ideal_ch;
    roundCursInBounds(t);
}

void
mvUp(Tile *t)
{
    t->curs.ln--;
    t->curs.ch = t->curs.ideal_ch;
    roundCursInBounds(t);
}

void
mvRight(Tile *t)
{
    t->curs.ch++;
    roundCursInBounds(t);
    t->curs.ideal_ch = t->curs.ch;
}

void
jmpDown(Tile *t, int x)
{
    int i;
    for (i = 0; i < x; i++)
        mvDown(t);
}

void
jmpUp(Tile *t, int x)
{
    int i;
    for (i = 0; i < x; i++)
        mvUp(t);
}

void
newLnBelow(Tile *t)
{
    LLCh *lns;

    lns = t->buf->lns;
    llchIns(lns, t->curs.ln + 1, initLCh());
    t->curs.ln++;
    t->curs.ch = 0;
}

void
newLnAbove(Tile *t)
{
    LLCh *lns;

    lns = t->buf->lns;
    llchIns(lns, t->curs.ln, initLCh());
    t->curs.ch = 0;
}

void
mvFastLeft(Tile *t)
{
    LCh *ln;
    char ch;

    if (t->curs.ch == 0)
        return;

    ln = t->buf->lns->items[t->curs.ln];
    ch = ln->items[t->curs.ch - 1];

    if (isalnum(ch) || ch == '_') { // go to start of alphnum
        while (t->curs.ch > 0) {
            ch = ln->items[t->curs.ch - 1];
            if (!isalnum(ch) && ch != '_')
                break;
            t->curs.ch--;
        }
    } else { // go to end of alphnum
        while (t->curs.ch > 0) {
            ch = ln->items[t->curs.ch - 1];
            if (isalnum(ch) || ch == '_')
                break;
            t->curs.ch--;
        }
    }

    t->curs.ideal_ch = t->curs.ch;
}

void
mvFullLeft(Tile *t)
{
    LCh *ln;
    ln = t->buf->lns->items[t->curs.ln];
    t->curs.ch = 0;
    while (t->curs.ch < ln->len && ln->items[t->curs.ch] == ' ')
        t->curs.ch++;
    t->curs.ideal_ch = t->curs.ch;
}

void
mvFastRight(Tile *t)
{
    LCh *ln;
    char ch;

    ln = t->buf->lns->items[t->curs.ln];
    ch = ln->items[t->curs.ch];

    if (t->curs.ch + 1 >= ln->len) {
        t->curs.ch = ln->len;
        t->curs.ideal_ch = t->curs.ch;
        return;
    }

    if (isalnum(ch) || ch == '_') { // go to last alphnum
        while (t->curs.ch < ln->len) {
            ch = ln->items[t->curs.ch];
            if (!isalnum(ch) && ch != '_')
                break;
            t->curs.ch++;
        }
    } else { // go to first alphnum
        while (t->curs.ch < ln->len) {
            ch = ln->items[t->curs.ch];
            if (isalnum(ch) || ch == '_')
                break;
            t->curs.ch++;
        }
    }

    t->curs.ideal_ch = t->curs.ch;
}

void
mvFullRight(Tile *t)
{
    t->curs.ch = t->buf->lns->items[t->curs.ln]->len;
    t->curs.ideal_ch = t->curs.ch;
}

void
rmNextCh(Tile *t)
{
    LCh *ln;
    ln = t->buf->lns->items[t->curs.ln];
    if (ln->len == 0 || t->curs.ch == ln->len) return;

    lchRm(ln, t->curs.ch);
}

void
swapNextCh(Tile *t, char ch)
{
    rmNextCh(t);
    typeChar(t, ch);
    mvLeft(t);
}

static void
roundCursInBounds(Tile *t)
{
    LLCh *lns;
    lns = t->buf->lns;

    if (t->curs.ln >= lns->len)
        t->curs.ln = lns->len - 1;
    if (t->curs.ln < 0)
        t->curs.ln = 0;

    if (t->curs.ch >= lns->items[t->curs.ln]->len)
        t->curs.ch = lns->items[t->curs.ln]->len;
    if (t->curs.ch < 0)
        t->curs.ch = 0;
}

inline static void
setTileCell(Rect *r, Frame *f, int *y, int *x, Cell c)
{
    if (*x < 0 || *x >= (r->x2 - r->x1) - 1) return;
    if (*y < 0 || *y >= (r->y2 - r->y1)) return;

    setFrameCell(f, (r->y1 + *y), (r->x1 + *x), c);
}

static int
calcNumLen(int lns)
{
    int xpadn = 0;
    while (lns > 0) {
        lns /= 10;
        xpadn++;
    }
    xpadn--;
    return xpadn;
}

static void
drawLnOnFrame(Tile *t, Frame *f, int y, int x, int ln_i)
{
    int ch_i, xpadn;
    Rect r;
    LLCh *lns;
    char ch;

    Cell bar, dot;

    bar = (Cell){.str = {(char)0xE2, (char)0x94, (char)0x82, 0}, .fg = 90};
    dot = (Cell){.str = {(char)0xC2, (char)0xB7, 0, 0}, .fg = 90};

    r = fixedFromPercRect(t->rect);

    lns = t->buf->lns;
    xpadn = x;

    // draw each line char
    for (ch_i = 0; ch_i < lns->items[ln_i]->len; ch_i++) {
        ch = lns->items[ln_i]->items[ch_i];
        if (ch == ' ')
            if (ch_i % 4 == 0
                    && ch_i + 3 < lns->items[ln_i]->len
                    && strncmp(lns->items[ln_i]->items + ch_i, "    ", 4) == 0)
                setTileCell(&r, f, &y, &x, bar);
            else
                setTileCell(&r, f, &y, &x, dot);
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
drawNumOnFrame(Tile *t, Frame *f, Mode mode, int y, int x, int num)
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
    int ch_i;
    Rect r;

    r = fixedFromPercRect(t->rect);

    // draw tile name
    str = t->buf->name;
    for (ch_i = 0; ch_i < (int)strlen(str); ch_i++) {
        ch = str[ch_i];
        setTileCell(&r, f, &y, &x, (Cell){.str = {ch, '\0'}});
        x++;
    }
}

static int
calcLnHeight(Rect *r, int *ln_len, int *xpadn)
{
    int ch_wid;
    ch_wid = ((r->x2 - 1) - r->x1 - (*xpadn + 2));
    if (*ln_len == 0 || ch_wid <= 0)
        return 1;
    else
        return ((*ln_len + ch_wid - 1) / ch_wid);
}

