#pragma once

typedef struct LLCh LLCh;

typedef struct Buf Buf;
struct Buf {
    char *name;
    LLCh *lns; // List of Lists of Chars
};

Buf* initBuf(const char *name);
void freeBufItems(Buf *buf);

void loadFile(Buf *buf, const char *fname);
