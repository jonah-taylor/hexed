#include "buf.h"
#include "utils/list.h"
#include "utils/xmem.h"

DEF_LIST(LCh, char, lch)
DEF_LIST(LLCh, LCh*, llch)
DEF_LIST(LBuf, Buf*, lb)

static void wipeBuf(Buf *buf, const char *bname);

Buf*
initBuf(const char *tmp_name)
{
    Buf *buf;

    buf = xmalloc(sizeof(Buf));
    *buf = (Buf){
        .name = xstrdup(tmp_name),
        .lns = initLLCh(),
    };

    return buf;
}

void
freeBuf(Buf *buf)
{
    int i;

    free(buf->name);

    for (i = 0; i < buf->lns->len; i++) {
        freeLCh(buf->lns->items[i]);
    }
    freeLLCh(buf->lns);

    free(buf);
}

void
loadFile(Buf *buf, const char *fname)
{
    FILE *fp;
    int row;
    char ch;

    fp = fopen(fname, "r");
    if (fp == NULL) return;

    free(buf->name);
    buf->name = strdup(fname);

    row = 0;
    for (;;) {
        llchPush(buf->lns, initLCh());

        while ((ch = fgetc(fp)) != '\n' && ch != EOF)
            lchPush(buf->lns->items[row], ch);

        if (ch == EOF) break;
        row++;
    }
}

void
loadBufList(Buf *buf, LBuf *lbuf)
{
    int buf_i, b_nm_i;
    char *bname;

    wipeBuf(buf, "bufslist");

    for (buf_i = 1; buf_i < lbuf->len; buf_i++) {
        llchPush(buf->lns, initLCh());
        bname = lbuf->items[buf_i]->name;
        for (b_nm_i = 0; b_nm_i < (int)strlen(bname); b_nm_i++)
            lchPush(buf->lns->items[buf_i - 1], bname[b_nm_i]);
    }
}

static void
wipeBuf(Buf *buf, const char *bname)
{
    int i;

    free(buf->name);

    for (i = 0; i < buf->lns->len; i++) {
        freeLCh(buf->lns->items[i]);
    }
    freeLLCh(buf->lns);

    *buf = (Buf){
        .name = xstrdup(bname),
        .lns = initLLCh(),
    };
}
