#pragma once

typedef struct Cursor Cursor;
typedef struct LLCh LLCh;
typedef struct LBuf LBuf;
typedef struct LDif LDif;

typedef struct Dif Dif;
struct Dif {
    int ln_sidx;
    int ln_eidx;
    LLCh *lns;
    Cursor *curs;
};

typedef struct Buf Buf;
struct Buf {
    char *name;
    LLCh *lns;
    LLCh *snapshot; // used for to find diff
    LDif *undo;
    LDif *redo;
};

Buf* initBuf(const char *name);
void freeBuf(Buf *buf);

void loadFile(Buf *buf, char *fname);
void loadBufList(Buf *buf, LBuf *lbuf);

void pushUndo(Buf *buf, Cursor *curs);
void popUndo(Buf *buf, Cursor *curs);

void popRedo(Buf *buf);
void clearRedo(Buf *buf);
