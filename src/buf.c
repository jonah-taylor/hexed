#include "buf.h"
#include "cursor.h"
#include "utils/list.h"
#include "utils/xmem.h"

#define MIN(a,b) ((a) < (b) ? (a) : (b))

DEF_LIST(LCh, char, lch)
DEF_LIST(LLCh, LCh*, llch)

DEF_LIST(LBuf, Buf*, lb)
DEF_LIST(LDif, Dif*, ld)

static Dif* newDifOnChng(Buf *buf, Cursor *curs);
static void freeDif(Dif *dif);
static void freeLDifContents(LDif *ldif);
static int lnEq(LCh *a, LCh *b);
static void wipeBufLns(Buf *buf);
static void updateSnapshot(Buf *buf);

Buf*
initBuf(const char *tmp_name)
{
    Buf *buf;

    buf = xmalloc(sizeof(Buf));
    *buf = (Buf){
        .name = xstrdup(tmp_name),
        .lns = initLLCh(),
        .snapshot = initLLCh(),
        .undo = initLDif(),
        .redo = initLDif(),
    };
    llchPush(buf->lns, initLCh());
    llchPush(buf->snapshot, initLCh());
    updateSnapshot(buf);

    return buf;
}

void
freeBuf(Buf *buf)
{
    int i;

    free(buf->name);
    for (i = 0; i < buf->lns->len; i++)
        freeLCh(buf->lns->items[i]);
    freeLLCh(buf->lns);

    for (i = 0; i < buf->snapshot->len; i++)
        freeLCh(buf->snapshot->items[i]);
    freeLLCh(buf->snapshot);

    freeLDifContents(buf->undo);
    freeLDif(buf->undo);
    freeLDifContents(buf->redo);
    freeLDif(buf->redo);

    free(buf);
}

void
loadFile(Buf *buf, char *fname)
{
    FILE *fp;
    int row;
    int ch;

    fp = fopen(fname, "r");
    if (fp == NULL) return;

    free(buf->name);
    buf->name = xstrdup(fname);

    wipeBufLns(buf);
    row = 0;
    for (;;) {
        llchPush(buf->lns, initLCh());

        while ((ch = fgetc(fp)) != '\n' && ch != EOF)
            lchPush(buf->lns->items[row], ch);

        if (ch == EOF) break;
        row++;
    }
    fclose(fp);
    updateSnapshot(buf);
}

void
loadBufList(Buf *buf, LBuf *lbuf)
{
    int buf_i, b_nm_i;
    char *bname;

    wipeBufLns(buf);

    if (lbuf->len <= 1) {
        llchPush(buf->lns, initLCh());
        return;
    }

    for (buf_i = 1; buf_i < lbuf->len; buf_i++) {
        llchPush(buf->lns, initLCh());
        bname = lbuf->items[buf_i]->name;
        for (b_nm_i = 0; b_nm_i < (int)strlen(bname); b_nm_i++)
            lchPush(buf->lns->items[buf_i - 1], bname[b_nm_i]);
    }

}

void
pushUndo(Buf *buf, Cursor *curs, int clear_redo)
{
    Dif *dif;

    // returns on no changes
    if ((dif = newDifOnChng(buf, curs)) == 0)
        return;

    // if the undo isn't pushed from a popped redo
    if (clear_redo)
        clearRedo(buf);

    updateSnapshot(buf);
    ldPush(buf->undo, dif);
}

void
popUndo(Buf *buf, Cursor *curs)
{
    Dif *dif;
    int ln_i, ch_i;

    pushUndo(buf, curs, 1);

    if (buf->undo->len == 0) return;

    dif = ldPop(buf->undo);

    // destroy new lines
    for (ln_i = dif->ln_eidx; ln_i >= dif->ln_sidx; ln_i--) {
        freeLCh(buf->lns->items[ln_i]);
        llchRm(buf->lns, ln_i);
    }

    // replace with old lines
    for (ln_i = 0; ln_i < dif->lns->len; ln_i++) {
        llchIns(buf->lns, dif->ln_sidx + ln_i, initLCh());
        for (ch_i = 0;
                ch_i < dif->lns->items[ln_i]->len;
                ch_i++) {
            lchPush(buf->lns->items[dif->ln_sidx + ln_i],
                    dif->lns->items[ln_i]->items[ch_i]);
        }
    }

    ldPush(buf->redo, newDifOnChng(buf, curs));

    // update the cursor
    *curs = *dif->curs;

    updateSnapshot(buf);

    freeDif(dif);
}

void
popRedo(Buf *buf, Cursor *curs)
{
    Dif *dif;
    int ln_i, ch_i;

    if (buf->redo->len == 0) return;

    dif = ldPop(buf->redo);

    // destroy new lines
    for (ln_i = dif->ln_eidx; ln_i >= dif->ln_sidx; ln_i--) {
        freeLCh(buf->lns->items[ln_i]);
        llchRm(buf->lns, ln_i);
    }

    // replace with old lines
    for (ln_i = 0; ln_i < dif->lns->len; ln_i++) {
        llchIns(buf->lns, dif->ln_sidx + ln_i, initLCh());
        for (ch_i = 0;
                ch_i < dif->lns->items[ln_i]->len;
                ch_i++) {
            lchPush(buf->lns->items[dif->ln_sidx + ln_i],
                    dif->lns->items[ln_i]->items[ch_i]);
        }
    }

    // update the cursor
    *curs = *dif->curs;

    pushUndo(buf, curs, 0);
    updateSnapshot(buf);

    freeDif(dif);
}

void
clearRedo(Buf *buf)
{
    freeLDifContents(buf->redo);
    buf->redo->len = 0;
}

static Dif*
newDifOnChng(Buf *buf, Cursor *curs)
{
    Dif *dif;
    int eidx_dif, ch_i, ln_i;

    dif = xmalloc(sizeof(Dif));
    dif->ln_sidx = 0;
    dif->ln_eidx = buf->lns->len - 1;
    eidx_dif = buf->snapshot->len - buf->lns->len;

    for (dif->ln_sidx = 0;
            dif->ln_sidx < MIN(buf->lns->len, buf->snapshot->len);
            dif->ln_sidx++) {

        if (!lnEq(buf->lns->items[dif->ln_sidx],
                buf->snapshot->items[dif->ln_sidx]))
            break;
    }
    // if nothing changed there's no dif
    if (dif->ln_sidx == buf->lns->len && dif->ln_sidx == buf->snapshot->len) {
        free(dif);
        return 0;
    }

    for (dif->ln_eidx = buf->lns->len - 1;
            dif->ln_eidx >= dif->ln_sidx
            && dif->ln_eidx + eidx_dif >= dif->ln_sidx;
            dif->ln_eidx--) {
        if (!lnEq(buf->lns->items[dif->ln_eidx],
                buf->snapshot->items[dif->ln_eidx + eidx_dif]))
            break;
    }

    dif->lns = initLLCh();
    for (ln_i = dif->ln_sidx; ln_i <= dif->ln_eidx + eidx_dif; ln_i++) {
        llchPush(dif->lns, initLCh());
        for (ch_i = 0; ch_i < buf->snapshot->items[ln_i]->len; ch_i++) {
            lchPush(dif->lns->items[ln_i - dif->ln_sidx],
                    buf->snapshot->items[ln_i]->items[ch_i]);
        }
    }

    dif->curs = xmalloc(sizeof(Cursor));
    *dif->curs = *curs;

    return dif;
}

static void
freeDif(Dif *dif)
{
    int i;

    for (i = 0; i < dif->lns->len; i++)
        freeLCh(dif->lns->items[i]);
    free(dif->curs);
    freeLLCh(dif->lns);
    free(dif);
}

static void
freeLDifContents(LDif *ldif)
{
    int i;

    for (i = 0; i < ldif->len; i++) {
        freeDif(ldif->items[i]);
    }
}

static int
lnEq(LCh *a, LCh *b)
{
    if (a->len != b->len) return 0;
    return memcmp(a->items, b->items, a->len) == 0;
}

static void
updateSnapshot(Buf *buf)
{
    int ln_i, ch_i;

    for (ln_i = 0; ln_i < buf->snapshot->len; ln_i++)
        freeLCh(buf->snapshot->items[ln_i]);
    freeLLCh(buf->snapshot);

    buf->snapshot = initLLCh();
    for (ln_i = 0; ln_i < buf->lns->len; ln_i++) {
        llchPush(buf->snapshot, initLCh());
        for (ch_i = 0; ch_i < buf->lns->items[ln_i]->len; ch_i++) {
            lchPush(buf->snapshot->items[ln_i], buf->lns->items[ln_i]->items[ch_i]);
        }
    }
}

static void
wipeBufLns(Buf *buf)
{
    int i;

    for (i = 0; i < buf->lns->len; i++)
        freeLCh(buf->lns->items[i]);
    freeLLCh(buf->lns);

    buf->lns = initLLCh();
}

