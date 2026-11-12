#include "frame.h"
#include "geometry.h"
#include "term.h"
#include "utils/list.h"
#include "utils/xmem.h"

DEF_LIST(LCell, Cell, lc)
DEF_LIST(LLCell, LCell*, llc)

static bool cellsEql(const Cell* a, const Cell* b);
static void clearCurrFrame(Frame *frame);

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
freeFrame(Frame *frame)
{
    int i;

    assert(frame->curr->len == frame->prev->len);

    for (i = 0; i < frame->curr->len; i++) {
        freeLCell(frame->curr->items[i]);
        freeLCell(frame->prev->items[i]);
    }

    freeLLCell(frame->curr);
    freeLLCell(frame->prev);

    free(frame);
}

void
reszFrame(Frame *frame, Tab tab)
{
    int r;
    int old_row_len;
 
    old_row_len = frame->curr->len;

    if (tab.rows == old_row_len)
    if (old_row_len > 0)
    if (tab.cols == frame->curr->items[0]->len)
        return;

    clearCurrFrame(frame);
    clearPrevFrame(frame);

    for (r = tab.rows; r < frame->curr->len; r++) {
        freeLCell(frame->curr->items[r]);
        freeLCell(frame->prev->items[r]);
    }
    llcResz(frame->curr, tab.rows);
    llcResz(frame->prev, tab.rows);

    for (r = old_row_len; r < frame->curr->len; r++) {
        frame->curr->items[r] = initLCell();
        frame->prev->items[r] = initLCell();
    }

    for (r = 0; r < frame->curr->len; r++) {
        lcResz(frame->curr->items[r], tab.cols);
        lcResz(frame->prev->items[r], tab.cols);
    }
}

void
setFrameCell(Frame *frame, int row, int col, Cell cell)
{
    if (row < 0 || col < 0
        || (int)row >= frame->curr->len
        || (int)col >= frame->curr->items[row]->len)
        return;
    frame->curr->items[row]->items[col] = cell;
}

void
drawFrame(Frame *frame)
{
    int r, c;
    Cell *curr_cell, *prev_cell;
    // Cell *above_cell, *below_cell;
    // Cell bar_cell, empty_cell;

    // bar_cell = (Cell){.str = {(char)0xE2, (char)0x94, (char)0x82, 0}, .fg = 90};
    // empty_cell = (Cell){0};

    saveCursorPos();
    moveCursorTo(0, 0);
    for (r = 0; r < frame->curr->len; r++) {
        for (c = 0; c < frame->curr->items[r]->len; c++) {
            curr_cell = &frame->curr->items[r]->items[c];
            prev_cell = &frame->prev->items[r]->items[c];

            // handle | above and below
            // if (r > 0)
            //     above_cell = &frame->curr->items[r - 1]->items[c];
            // else
            //     above_cell = &empty_cell;
            // if (r < frame->curr->len - 1)
            //     below_cell = &frame->curr->items[r + 1]->items[c];
            // else
            //     below_cell = &empty_cell;

            // if (cellsEql(above_cell, below_cell))
            // if (cellsEql(above_cell, &bar_cell))
            // if (curr_cell->str[0] == ' ')
            //     *curr_cell = bar_cell;

            if (cellsEql(curr_cell, prev_cell))
                continue;

            setColors(curr_cell->fg, curr_cell->bg);
            drawStrAtLoc(r, c, curr_cell->str);
        }
    }

    LLCell *tmp = frame->curr;
    frame->curr = frame->prev;
    frame->prev = tmp;

    clearCurrFrame(frame);
    loadCursorPos();
}

static bool
cellsEql(const Cell* a, const Cell* b)
{
    return a->fg == b->fg
        && a->bg == b->bg
        && strncmp(a->str, b->str, sizeof(a->str)) == 0;
}

static void
clearCurrFrame(Frame *frame)
{
    int r, c;
    for (r = 0; r < frame->curr->len; r++) {
        for (c = 0; c < frame->curr->items[r]->len; c++) {
            frame->curr->items[r]->items[c] = (Cell){
                .str = " ",
                .fg = -1,
                .bg = -1,
            };
        }
    }
}

void
clearPrevFrame(Frame *frame)
{
    int r, c;
    for (r = 0; r < frame->prev->len; r++) {
        for (c = 0; c < frame->prev->items[r]->len; c++) {
            frame->prev->items[r]->items[c] = (Cell){0};
        }
    }
}
