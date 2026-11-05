#include "buf.h"

#include "list.h"

#include "utils/xmem.h"

Buf*
initBuf(char *tmp_name)
{
    Buf *buf = xmalloc(sizeof(Buf));
    char *name = xstrdup(tmp_name);
    *buf = (Buf){
        .name = name,
        .lns = initList(sizeof(List)),
    };
    return buf;
}

void
freeBuf(Buf *buf)
{
    size_t i;
    free(buf->name);
    for (i = 0; i < buf->lns->len; i++)
        freeList(lget((List*)buf->lns->items, i));
    freeList(buf->lns);

    free(buf);
}
