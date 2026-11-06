#include "buf.h"

#include "utils/list.h"
#include "utils/xmem.h"

DEF_LIST(LCh, char, lch)
DEF_LIST(LLCh, LCh, llch)

Buf*
initBuf(char *tmp_name)
{
    Buf *buf = xmalloc(sizeof(Buf));
    char *name = xstrdup(tmp_name);
    *buf = (Buf){
        .name = name,
        .lns = initLLCh(),
    };
    return buf;
}

void
freeBufItems(Buf *buf)
{
    size_t i;
    free(buf->name);
    for (i = 0; i < buf->lns->len; i++) {
        freeLChItems(&buf->lns->items[i]);
        free(&buf->lns->items[i]);
    }
    freeLLChItems(buf->lns);
    free(buf->lns);
}
