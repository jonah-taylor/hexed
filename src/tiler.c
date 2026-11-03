#include "tiler.h"

#include "cursor.h"
#include "tile.h"
#include "term.h"
#include "geometry.h"
#include <stdbool.h>
#include <stdlib.h>

#define TILES_INIT_CAP 4

void
initTiler(Tiler *tiler)
{
    *tiler = (Tiler){
        .tiles = malloc(TILES_INIT_CAP * sizeof(Tile)),
        .ts_len = 1,
        .ts_cap = TILES_INIT_CAP,
        .sel_idx = 0,
    };

    initTile(
        &tiler->tiles[0],
        (Rect){
            .x1 = 0,
            .y1 = 0,
            .x2 = PERC_DENOM,
            .y2 = PERC_DENOM,
        },
        (Cursor){
            .x = 1,
            .y = 1,
        }
    );
}

void
deinitTiler(Tiler *tiler)
{
    free(tiler->tiles);
}

void
drawTiles(Tiler *tiler)
{
    Tile *tile;
    size_t i;
    for (i = 0; i < tiler->ts_len; i++) {
        drawTile(&tiler->tiles[i]);
    }
    tile = getSel(tiler);
    moveCursorTo(
        fixedFromPercY(tile->rect.y1) + tile->cursor.y,
        fixedFromPercX(tile->rect.x1) + tile->cursor.x
    );
}

Tile*
getSel(Tiler *tiler)
{
    return &tiler->tiles[tiler->sel_idx];
}

void
newTile(Tiler *tiler, Dir dir)
{
    Tile *tile;
    size_t x1, x2, y1, y2;

    tile = getSel(tiler);
    x1 = tile->rect.x1;
    x2 = tile->rect.x2;
    y1 = tile->rect.y1;
    y2 = tile->rect.y2;

    switch (dir) {
    case UP:
    case DOWN:
        if ((y2 - y1) / 2 < PERC_DENOM / 20)
            return;
        break;

    case LEFT:
    case RIGHT:
        if ((x2 - x1) / 2 < PERC_DENOM / 20)
            return;
        break;
    }

    switch (dir) {
    case UP:
        y2 = y1 + (y2 - y1) / 2;
        y2 = (y2 + 4) / 8 * 8;
        tile->rect.y1 = y2;
        break;
    case DOWN:
        y1 = y1 + (y2 - y1) / 2;
        y1 = (y1 + 4) / 8 * 8;
        tile->rect.y2 = y1;
        break;
    case LEFT:
        x2 = x1 + (x2 - x1) / 2;
        x2 = (x2 + 4) / 8 * 8;
        tile->rect.x1 = x2;
        break;
    case RIGHT:
        x1 = x1 + (x2 - x1) / 2;
        x1 = (x1 + 4) / 8 * 8;
        tile->rect.x2 = x1;
        break;
    }

    if (tiler->ts_len == tiler->ts_cap) {
        tiler->ts_cap *= 2;
        tiler->tiles = realloc(
            tiler->tiles,
            tiler->ts_cap * sizeof(*tiler->tiles)
        );
    }

    initTile(
        &tiler->tiles[tiler->ts_len],
        (Rect){
            .x1 = x1,
            .y1 = y1,
            .x2 = x2,
            .y2 = y2,
        },
        (Cursor){
            .x = 1,
            .y = 1,
        }
    );

    tiler->sel_idx = tiler->ts_len;
    tiler->ts_len++;
}

int
getTileIdxAtPoint(Tiler *tiler, size_t x, size_t y, bool fixed)
{
    Rect *rect;
    size_t i;

    for (i = 0; i < tiler->ts_len; i++) {
        rect = &tiler->tiles[i].rect;
        if (fixed) {
            if (fixedFromPercX(rect->x1) <= x && x <= fixedFromPercX(rect->x2))
            if (fixedFromPercY(rect->y1) <= y && y <= fixedFromPercY(rect->y2))
                return i;
        } else {
            if (rect->x1 <= x && x <= rect->x2)
            if (rect->y1 <= y && y <= rect->y2)
                return i;
        }
    }
    return -1;
}

void
selTileInCursorDir(Tiler *tiler, Dir dir)
{
    Tile *tile;
    Rect *rect;
    int new_sel;
    size_t x, y;

    tile = getSel(tiler);
    x = fixedFromPercX(tile->rect.x1) + tile->cursor.x;
    y = fixedFromPercY(tile->rect.y1) + tile->cursor.y;

    rect = &tile->rect;
    switch (dir) {
    case UP:
        y = fixedFromPercY(rect->y1) - 1;
        break;
    case DOWN:
        y = fixedFromPercY(rect->y2) + 1;
        break;
    case LEFT:
        x = fixedFromPercX(rect->x1) - 1;
        break;
    case RIGHT:
        x = fixedFromPercX(rect->x2) + 1;
        break;
    }

    new_sel = getTileIdxAtPoint(tiler, x, y, true);
    if (new_sel != -1)
        tiler->sel_idx = new_sel;
}

size_t
countTilesAtPoint(Tiler *tiler, size_t x, size_t y)
{
    size_t count, i;
    Rect *rect;

    count = 0;
    for (i = 0; i < tiler->ts_len; i++) {
        rect = &tiler->tiles[i].rect;
        if (rect->x1 <= x && x <= rect->x2)
        if (rect->y1 <= y && y <= rect->y2)
            count++;
    }
    return count;
}

void
walkSelEdge(Tiler *tiler, Dir dir, size_t *in[], size_t *i_len, size_t *out[], size_t *o_len)
{
    int x, y;
    int shorter, longer;
    size_t idx, tap;
    size_t i_cap, o_cap;

    *in = malloc(sizeof(size_t));
    *i_len = 0;
    i_cap = 1;
    *out = malloc(sizeof(size_t));
    *o_len = 0;
    o_cap = 1;

    x = (getSel(tiler)->rect.x2 + getSel(tiler)->rect.x1) / 2;
    y = (getSel(tiler)->rect.y2 + getSel(tiler)->rect.y1) / 2;

    // start at the middle of the edge
    switch (dir) {
    case UP:
        y = getSel(tiler)->rect.y1;
        break;
    case DOWN:
        y = getSel(tiler)->rect.y2;
        break;
    case LEFT:
        x = getSel(tiler)->rect.x1;
        break;
    case RIGHT:
        x = getSel(tiler)->rect.x2;
        break;
    }

    // get the ends of the edge
    switch (dir) {
    case UP:
    case DOWN:
        shorter = x;
        longer = x;
        while ((tap = countTilesAtPoint(tiler, longer, y)) == 3 || tap == 2)
            longer++;
        while ((tap = countTilesAtPoint(tiler, shorter, y)) == 3 || tap == 2)
            shorter--;
        break;
    case LEFT:
    case RIGHT:
        shorter = y;
        longer = y;
        while ((tap = countTilesAtPoint(tiler, x, longer)) == 3 || tap == 2)
            longer++;
        while ((tap = countTilesAtPoint(tiler, x, shorter)) == 3 || tap == 2)
            shorter--;
        break;
    }
    longer -= 2;
    shorter += 2;

    while (shorter < longer) {
        // fill in
        switch (dir) {
        case UP:
            idx = getTileIdxAtPoint(tiler, shorter, y + 1, false);
            break;
        case DOWN:
            idx = getTileIdxAtPoint(tiler, shorter, y - 1, false);
            break;
        case LEFT:
            idx = getTileIdxAtPoint(tiler, x + 1, shorter, false);
            break;
        case RIGHT:
            idx = getTileIdxAtPoint(tiler, x - 1, shorter, false);
            break;
        }
        if (idx + 1 != 0 && (*i_len == 0 || (*in)[*i_len - 1] != idx)) {
            if (*i_len >= i_cap) {
                i_cap *= 2;
                *in = realloc(*in, i_cap * sizeof(size_t));
            }
            (*in)[(*i_len)++] = idx;
        }
        // fill out
        switch (dir) {
        case UP:
            idx = getTileIdxAtPoint(tiler, shorter, y - 1, false);
            break;
        case DOWN:
            idx = getTileIdxAtPoint(tiler, shorter, y + 1, false);
            break;
        case LEFT:
            idx = getTileIdxAtPoint(tiler, x - 1, shorter, false);
            break;
        case RIGHT:
            idx = getTileIdxAtPoint(tiler, x + 1, shorter, false);
            break;
        }
        if (idx + 1 != 0 && (*o_len == 0 || (*out)[*o_len - 1] != idx)) {
            if (*o_len >= o_cap) {
                o_cap *= 2;
                *out = realloc(*out, o_cap * sizeof(size_t));
            }
            (*out)[(*o_len)++] = idx;
        }
        shorter++;
    }
}

void
rmSel(Tiler *tiler)
{
    size_t i, dir;
    Rect *o_rect, *i_rect;
    size_t *inner, *outer;
    size_t i_len, o_len;

    for (dir = 0; dir < 4; dir++) {
        walkSelEdge(tiler, dir, &inner, &i_len, &outer, &o_len);
        if (i_len == 1 && o_len > 0)
            break;
        free(inner);
        free(outer);
    }

    if (dir == 4) return;

    i_rect = &tiler->tiles[inner[0]].rect;

    switch (dir) {
    case UP:
    case DOWN:
        for (i = 0; i < o_len; i++) {
            o_rect = &tiler->tiles[outer[i]].rect;
            if (i_rect->y1 < o_rect->y1) o_rect->y1 = i_rect->y1;
            if (i_rect->y2 > o_rect->y2) o_rect->y2 = i_rect->y2;
        }
        break;
    case LEFT:
    case RIGHT:
        for (i = 0; i < o_len; i++) {
            o_rect = &tiler->tiles[outer[i]].rect;
            if (i_rect->x1 < o_rect->x1) o_rect->x1 = i_rect->x1;
            if (i_rect->x2 > o_rect->x2) o_rect->x2 = i_rect->x2;
        }
        break;
    }
    deinitTile(&tiler->tiles[inner[0]]);
    tiler->tiles[inner[0]] = tiler->tiles[tiler->ts_len - 1];
    if (outer[0] != tiler->ts_len - 1)
        tiler->sel_idx = outer[0];

    tiler->ts_len--;
    free(inner);
    free(outer);
}

void
reszSel(Tiler *tiler, Dir dir, bool growing)
{
    size_t i;
    Rect *rect;
    size_t *inner, *outer;
    size_t i_len, o_len;
    size_t vel, min;

    vel = 8; // FIX MAGIC
    min = vel;

    walkSelEdge(tiler, dir, &inner, &i_len, &outer, &o_len);

    // shrink in opposite direction if on the edge
    if (growing && o_len == 0) {
        free(inner);
        free(outer);
        switch (dir) {
        case UP:
            reszSel(tiler, DOWN, false);
            return;
        case DOWN:
            reszSel(tiler, UP, false);
            return;
        case LEFT:
            reszSel(tiler, RIGHT, false);
            return;
        case RIGHT:
            reszSel(tiler, LEFT, false);
            return;
        }
    }

    // min size check on shrinking side
    for (i = 0; i < ((growing) ? o_len : i_len); i++) {
        rect = &tiler->tiles[(growing) ? outer[i] : inner[i]].rect;
        switch (dir) {
        case UP:
        case DOWN:
            if (rect->y2 - rect->y1 <= min) {
                free(inner);
                free(outer);
                return;
            }
            break;
        case LEFT:
        case RIGHT:
            if (rect->x2 - rect->x1 <= min) {
                free(inner);
                free(outer);
                return;
            }
            break;
        }
    }

    // adjust the inner aligned
    for (i = 0; i < i_len; i++) {
        rect = &tiler->tiles[inner[i]].rect;
        switch (dir) {
        case UP:
            rect->y1 += (growing) ? -vel : vel;
            break;
        case DOWN:
            rect->y2 += (growing) ? vel : -vel;
            break;
        case LEFT:
            rect->x1 += (growing) ? -vel : vel;
            break;
        case RIGHT:
            rect->x2 += (growing) ? vel : -vel;
            break;
        }
    }

    // adjust the outer aligned
    for (i = 0; i < o_len; i++) {
        rect = &tiler->tiles[outer[i]].rect;
        switch (dir) {
        case UP:
            rect->y2 += (growing) ? -vel : vel;
            break;
        case DOWN:
            rect->y1 += (growing) ? vel : -vel;
            break;
        case LEFT:
            rect->x2 += (growing) ? -vel : vel;
            break;
        case RIGHT:
            rect->x1 += (growing) ? vel : -vel;
            break;
        }
    }

    free(inner);
    free(outer);
}
