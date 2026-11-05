#include "buf.h"

#include "list.h"

#include "utils/xmem.h"

DEF_LIST(char, LCh, lch)
DEF_LIST(LCh, LLCh, llch)

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
freeBuf(Buf *buf)
{
    size_t i;
    free(buf->name);
    for (i = 0; i < buf->lns->len; i++)
        freeLCh(&buf->lns->items[i]);
    freeLLCh(buf->lns);

    free(buf);
}
