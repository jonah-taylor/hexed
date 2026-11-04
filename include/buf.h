#pragma once

typedef struct List List;

typedef struct Buf Buf;
struct Buf {
    char *name;
    List *lns;
};

Buf* initBuf(char *name);
void freeBuf(Buf *buf);
