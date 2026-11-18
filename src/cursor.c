#include "cursor.h"

#define SWAP(A, B) \
    do { \
        typeof(A) T = A; \
        A = B; \
        B = T; \
    } while (0);

void
swapVCursToTop(Cursor *curs)
{
    int will_swap;

    will_swap = 0;
    if (curs->vln > curs->ln) {
        will_swap = 1;
    } else if (curs->vln == curs->ln) {
        if (curs->vch > curs->ch) {
            will_swap = 1;
        }
    }

    if (will_swap) {
        SWAP(curs->vln, curs->ln);
        SWAP(curs->vch, curs->ch);
        curs->ch++;
    }
}
