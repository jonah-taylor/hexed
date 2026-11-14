#pragma once

typedef struct LLCh LLCh;
typedef struct LBuf LBuf;

typedef struct Buf Buf;
struct Buf {
    char *name;
    LLCh *lns; // List of Lists of Chars
};

Buf* initBuf(const char *name);
void freeBuf(Buf *buf);

void loadFile(Buf *buf, char *fname);
void loadBufList(Buf *buf, LBuf *lbuf);
