#pragma once

typedef struct Cursor Cursor;
struct Cursor {
    int ln;
    int ch;
    int ideal_ch;

    int x;
    int y;

    int vln;
    int vch;
};

void swapVCursToTop(Cursor *curs);
void swapVCursToBot(Cursor *curs);
