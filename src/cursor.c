#include "cursor.h"
#include "utils/xmem.h"

Cursor*
initCursor()
{
    Cursor *cursor;

    cursor = xmalloc(sizeof(Cursor));
    *cursor = (Cursor){
        .x = 1,
        .y = 1,
    };
    return cursor;
}

