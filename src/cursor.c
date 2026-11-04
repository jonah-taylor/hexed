#include "cursor.h"

#include "utils/xmem.h"

Cursor*
initCursor()
{
    Cursor *cursor = xmalloc(sizeof(Cursor));
    *cursor = (Cursor){
        .x = 1,
        .y = 1,
    };
    return cursor;
}

void
freeCursor(Cursor *cursor)
{
    free(cursor);
    cursor = 0;
}
