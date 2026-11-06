#pragma once

#include <stddef.h>

typedef struct Tab Tab;

typedef struct Cell Cell;
struct Cell {
    char str[5];
    int fg;
    int bg;
};

typedef struct LLCell LLCell;
typedef struct Frame Frame;
struct Frame {
    LLCell *prev;
    LLCell *curr;
};

Frame *initFrame();
void freeFrameItems(Frame *frame);

void clearCurrFrame(Frame *frame);
void reszFrame(Frame *frame, Tab tab);
void setCell(Frame *frame, int row, int col, Cell cell);
void drawFrame(Frame *frame);
