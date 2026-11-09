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

