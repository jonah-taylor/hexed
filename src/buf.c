#include "buf.h"

#include "utils/list.h"
#include "utils/xmem.h"

DEF_LIST(LCh, char, lch)
DEF_LIST(LLCh, LCh*, llch)

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
    size_t i;

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
    size_t row, col;
    char ch;

    fp = fopen(fname, "r");
    if (fp == NULL) return;

    free(buf->name);
    buf->name = strdup(fname);

    row = 0;
    for (;;) {
        col = 0;

        llchPush(buf->lns, initLCh());
        row++;

        while ((ch = fgetc(fp)) != '\n' && ch != EOF)
            buf->lns->items[row]->items[col++] = ch;

        if (ch == EOF) break;
    }
}

