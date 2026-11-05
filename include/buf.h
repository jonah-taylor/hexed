#pragma once

typedef struct LLCh LLCh;

typedef struct Buf Buf;
struct Buf {
    char *name;
    LLCh *lns; // List of Lists of Chars
};

Buf* initBuf(char *name);
void freeBuf(Buf *buf);
