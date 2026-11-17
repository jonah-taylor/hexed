#include "cmdgen.h"
#include "term.h"

#include "utils/xmem.h"

#define NUM_CAP 100000

CmdGen
*initCmdGen()
{
    CmdGen *cg;
    cg = xcalloc(sizeof(CmdGen));
    return cg;
}

void
freeCmdGen(CmdGen *cg)
{
    free(cg);
}

void
getchForCmd(CmdGen *cg)
{
    char key;
    Cmd *c;

    key = getch();
    c = &cg->curr;

    // handle number
    if (key >= '0' && key <= '9' && c->num < NUM_CAP) {
        c->num *= 10;
        c->num += (key - '0');
        if (c->num >= NUM_CAP)
            c->num = NUM_CAP - 1;
        return;
    }

    // handle special
    if (key == '\x1b') {
        c->keys[c->klen] = key;
        c->klen++;

        c->klen += read(STDIN_FILENO, &c->keys[c->klen], sizeof(c->keys) - c->klen);
        if (c->klen == 1)
            *c = (Cmd){0};

        return;
    }

    // handle char
    c->keys[c->klen] = key;
    c->klen++;
}

void
shiftKeysLeft(CmdGen *cg, int i)
{
    while (i > 0 && cg->curr.klen > 0) {
        cg->curr.klen--;
        memmove(cg->curr.keys, &cg->curr.keys[1], cg->curr.klen);
        i--;
    }
}

void
usedCmd(CmdGen *cg)
{
    if (cg->curr.num > 0)
        cg->prev = cg->curr;
    cg->curr = (Cmd){0};
}
