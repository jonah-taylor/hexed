#include "frame.h"

#include "geometry.h"
#include "term.h"

#include "utils/list.h"
#include "utils/xmem.h"

DEF_LIST(LCell, Cell, lc)
DEF_LIST(LLCell, LCell, llc)

Frame*
initFrame()
{
    Frame *frame;

    frame = xmalloc(sizeof(*frame));
    *frame = (Frame){
        .curr = initLLCell(),
        .prev = initLLCell(),
    };
    return frame;
}

void
freeFrameItems(Frame *frame)
{
    size_t i;

    for (i = 0; i < frame->curr->len; i++)
        freeLCellItems(&frame->curr->items[i]);
    freeLLCellItems(frame->curr);
    free(frame->curr);

    for (i = 0; i < frame->prev->len; i++)
        freeLCellItems(&frame->prev->items[i]);
    freeLLCellItems(frame->prev);
    free(frame->prev);
}

void
clearCurrFrame(Frame *frame)
{
    size_t r, c;
    for (r = 0; r < frame->curr->len; r++) {
        for (c = 0; c < frame->curr->items[r].len; c++) {
            frame->curr->items[r].items[c] = (Cell){0};
        }
    }
}

void
reszFrame(Frame *frame, Tab tab)
{
    size_t r;
    llcResz(frame->curr, tab.rows + 1);
    llcResz(frame->prev, tab.rows + 1);
    for (r = 0; r < frame->curr->len; r++) {
        lcResz(&frame->curr->items[r], tab.cols + 1);
        lcResz(&frame->prev->items[r], tab.cols + 1);
    }
}

void
setCell(Frame *frame, int row, int col, Cell cell)
{
    if (row < 0 || col < 0
        || (size_t)row >= frame->curr->len
        || (size_t)col >= frame->curr->items[row].len)
        return;
    frame->curr->items[row].items[col] = cell;
}

bool
cellsREql(Cell* a, Cell* b)
{
    return a->fg == b->fg
        && a->bg == b->bg
        && strncmp(a->str, b->str, sizeof(a->str) == 0);
}

void
drawFrame(Frame *frame)
{
    size_t r, c;

    saveCursorPos();
    moveCursorTo(0, 0);
    for (r = 0; r < frame->curr->len; r++) {
        for (c = 0; c < frame->curr->items[r].len; c++) {
            Cell *curr_cell = &frame->curr->items[r].items[c];
            Cell *prev_cell = &frame->prev->items[r].items[c];

            if (cellsREql(curr_cell, prev_cell))
                continue;

            // setColors(cell->fg, cell->bg);
            if (curr_cell->str[0] == '\0') {
                drawStrAtLoc(r, c, " ");
            } else {
                drawStrAtLoc(r, c, curr_cell->str);
            }
        }
    }

    LLCell *tmp = frame->curr;
    frame->curr = frame->prev;
    frame->prev = tmp;

    clearCurrFrame(frame);
    loadCursorPos();
}

