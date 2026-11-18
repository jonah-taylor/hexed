#include <signal.h>
#include <limits.h>

#include "app.h"
#include "buf.h"
#include "client.h"
#include "cmdgen.h"
#include "cursor.h"
#include "frame.h"
#include "geometry.h"
#include "server.h"
#include "term.h"
#include "tile.h"
#include "tiler.h"
#include "utils/list.h"
#include "utils/xmem.h"

DEF_LIST(LBuf, Buf*, lb)

static void freeApp(App *app);
static int tryCmd(App *app, Cmd *cmd);

enum CmdStat {
    USED,
    RERUN,
    INCOMPLETE,
    QUIT,
};
typedef enum CmdStat CmdStat;

int
main(int argc, char *argv[])
{
    App *app;
    char lbufs_name[64];
    CmdStat cmdstat;
    int i, isnum_arg1;

    if (argc > 1) {
        isnum_arg1 = 1;
        for (i = 0; i < (int)strlen(argv[1]); i++) {
            if (!isdigit(argv[1][i]))
                isnum_arg1 = 0;
        }
        if (isnum_arg1) {
            client(atoi(argv[1]), argc - 2, (argv + 2));
            return 0;
        }
    }

    app = xmalloc(sizeof(*app));
    *app = (App){
        .mode = EDITING,
        .refr_bufs = 1,
        .fd = -1,
        .port = -1,

        .cg = initCmdGen(),
        .lbufs = initLBuf(),
        .frame = initFrame(),
        .tiler = NULL,
    };

    // fills the fd and port fields
    if (startServer(&app->fd, &app->port) < 0) {
        freeApp(app);
        return 0;
    }

    snprintf(lbufs_name, sizeof(lbufs_name), "PORT %d", app->port);
    lbPush(app->lbufs, initBuf(lbufs_name));

    app->tiler = initTiler(app->lbufs->items[0]);

    if (argc > 1)
        client(app->port, argc - 1, (argv + 1));

    if (enableRaw()) {
        perror("raw mode");
        exit(1);
    }
    enterAltScreen();
    clearScreen();

    for (;;) {

        flushServer(app);

        if (app->refr_bufs) {
            loadBufList(app->lbufs->items[0], app->lbufs);
            app->refr_bufs = 0;
        }

        reszFrame(app->frame, getTermSz());
        drawTilesOnFrame(app->tiler, app->frame, app->mode, &app->cg->curr);

        drawFrame(app->frame);
        updateCursor(getSel(app->tiler));
        fflush(stdout);

        getchForCmd(app->cg);
        do {
            cmdstat = tryCmd(app, &app->cg->curr);
            if (cmdstat == USED) {
                for (i = 1; i < app->cg->curr.num; i++)
                    cmdstat = tryCmd(app, &app->cg->curr);
                usedCmd(app->cg);
            } else if (cmdstat == QUIT)
                goto cleanup;
        } while (cmdstat == RERUN);
    }

cleanup:
    freeApp(app);
    exitAltScreen();
    disableRaw();
    return 0;
}

static int
tryCmd(App *app, Cmd *c)
{
    Cmd cmd_copy;
    Tile *tile;
    char key;
    int idx;

    tile = getSel(app->tiler);

    if (c->klen == 0)
        return INCOMPLETE;
    key = c->keys[0];

    // mode agnostic
    switch (key) {
    case '\t':
        app->mode = EDITING;
        setCursorBlock();
        return USED;
    case '\x08': // backspace
    case '\x7f':
        typeBksp(tile);
        return USED;
    case '\r':
    case '\n':
        if ((idx = typeEnter(tile)) && idx < app->lbufs->len) {
            saveCursToBkCv(tile);
            tile->buf = app->lbufs->items[idx];
            *tile->curs = getCursFromBkCv(tile);
        }
        return USED;
    case '\x1b': // arrow keys

        if (c->klen < 3)
            return USED;
        key = c->keys[2];

        switch (key) {
        case 'A':
            mvUp(tile);
            return USED;
        case 'B':
            mvDown(tile);
            return USED;
        case 'C':
            mvRight(tile);
            return USED;
        case 'D':
            mvLeft(tile);
            return USED;
        case '1':
            if (c->klen < 8)
                return USED;
            if (strncmp((c->keys + 3), "05;5u", 5) == 0) {
                typeTab(tile);
                return USED;
            }
        }
    }

    // typing
    if (app->mode == TYPING) {
        typeChar(tile, key);
        *c = (Cmd){0};
        return USED;
    }

    // editing/resizing
    switch(key) {

    case 'a': *c = app->cg->prev; return RERUN;

    case 'b':
        app->refr_bufs = 1;
        saveCursToBkCv(tile);
        tile->buf = app->lbufs->items[0];
        *tile->curs = getCursFromBkCv(tile);
        return USED;

    case 'c':
        if (app->mode == CHHIGHLIGHT) {
            tryCmd(app, &(Cmd){.keys = "d", .klen = 1, .num = 0});
            app->mode = TYPING;
            setCursorBar();
            return USED;
        }
        if (app->mode == LNHIGHLIGHT) {
            tryCmd(app, &(Cmd){.keys = "d", .klen = 1, .num = 0});
            app->mode = TYPING;
            setCursorBar();
            return USED;
        }
        if (c->klen == 1) return INCOMPLETE;
        key = c->keys[1];
        switch (key) {
        case 'c': rmLn(tile); app->mode = TYPING; setCursorBar();
                  return USED;
        case 'h': rmLnBeforeCurs(tile); app->mode = TYPING; setCursorBar();
                  return USED;
        case 'l': rmLnAfterCurs(tile); app->mode = TYPING; setCursorBar();
                  return USED;
        case 'j': rmLnBelow(tile); app->mode = TYPING; setCursorBar();
                  return USED;
        case 'k': rmLnAbove(tile); app->mode = TYPING; setCursorBar();
                  return USED;
        case 'w':
            app->mode = CHHIGHLIGHT;
            tryCmd(app, &(Cmd){.keys = "w", .klen = 1, .num = 0});
            tryCmd(app, &(Cmd){.keys = "c", .klen = 1, .num = 0});
            return USED;
        default: shiftKeysLeft(app->cg, c->klen - 1); return RERUN;
        }

    case 'C': rotTilesCW(app->tiler); return USED;

    case 'd':
        if (app->mode == CHHIGHLIGHT) {
            swapVCursToTop(tile->curs);
            while (tile->curs->ln > tile->curs->vln)
                typeBksp(tile);
            while (tile->curs->ch > tile->curs->vch)
                typeBksp(tile);
            app->mode = EDITING;
            setCursorBlock();
            return USED;
        }

        if (app->mode == LNHIGHLIGHT) {
            swapVCursToBot(tile->curs);
            for (idx = tile->curs->vln - tile->curs->ln + 1; idx > 0; idx--)
                rmLn(tile);
            app->mode = EDITING;
            setCursorBlock();
            return USED;
        }

        if (c->klen == 1) return INCOMPLETE;
        key = c->keys[1];
        switch (key) {
        case 'd': rmLn(tile); return USED;
        case 'h': rmLnBeforeCurs(tile); return USED;
        case 'l': rmLnAfterCurs(tile); return USED;
        case 'j': rmLnBelow(tile); return USED;
        case 'k': rmLnAbove(tile); return USED;
        case 'w':
            app->mode = CHHIGHLIGHT;
            tryCmd(app, &(Cmd){.keys = "w", .klen = 1, .num = 0});
            tryCmd(app, &(Cmd){.keys = "d", .klen = 1, .num = 0});
            return USED;
        default: shiftKeysLeft(app->cg, c->klen - 1); return RERUN;
        }

    case 'D': rmSel(app->tiler); return USED;

    case 'h': (app->mode == RESIZING) ?
              reszSel(app->tiler, LEFT, true) : mvLeft(tile);
        return USED;

    case 'H': selTileInCursorDir(app->tiler, LEFT);
              app->mode = EDITING; return USED;
    case 'i': mvFastLeft(tile); return USED;
    case 'I': mvFullLeft(tile); return USED;

    case 'j': (app->mode == RESIZING) ?
            reszSel(app->tiler, DOWN, true) : mvDown(tile);
        return USED;

    case 'J': selTileInCursorDir(app->tiler, DOWN);
              app->mode = EDITING; return USED;

    case 'k': (app->mode == RESIZING) ?
        reszSel(app->tiler, UP, true) : mvUp(tile); return USED;

    case 'K': selTileInCursorDir(app->tiler, UP);
              app->mode = EDITING; return USED;

    case 'l': (app->mode == RESIZING) ?
            reszSel(app->tiler, RIGHT, true) : mvRight(tile);
        return USED;

    case 'L': selTileInCursorDir(app->tiler, RIGHT);
              app->mode = EDITING; return USED;

    case 'm': jmpDown(tile, 10); return USED;
    case 'M': jmpUp(tile, 10); return USED;
    case 'n': newLnBelow(tile); return USED;
    case 'N': newLnAbove(tile); return USED;
    case 'o': mvFastRight(tile); return USED;
    case 'O': mvFullRight(tile); return USED;

    case 'q':
        if (c->klen == 1) return INCOMPLETE;
        key = c->keys[1];
        switch (key) {
        case 'q': return QUIT;
        default: shiftKeysLeft(app->cg, c->klen - 1); return RERUN;
        }

    case 'R': app->mode = (app->mode == RESIZING) ? EDITING : RESIZING; return USED;

    case 's':
        if (c->klen == 1) return INCOMPLETE;
        cmd_copy = *c;
        shiftKeysLeft(app->cg, 1);
        rmNextCh(tile);
        app->mode = TYPING;
        tryCmd(app, &app->cg->curr);
        *c = cmd_copy;
        app->mode = EDITING;
        mvLeft(tile);
        return USED;

    case 'S':
        if (c->klen == 1) return INCOMPLETE;
        key = c->keys[1];

        switch(key) {
        case 'h': swapCursorDir(app->tiler, LEFT); return USED;
        case 'j': swapCursorDir(app->tiler, DOWN); return USED;
        case 'k': swapCursorDir(app->tiler, UP); return USED;
        case 'l': swapCursorDir(app->tiler, RIGHT); return USED;
        default: shiftKeysLeft(app->cg, c->klen - 1); return RERUN;
        }

    case 't':
        if (c->klen == 1)
            return INCOMPLETE;
        key = c->keys[1];
        switch(key) {
        case 'h': newTile(app->tiler, LEFT, app->lbufs->items[0]);
                  app->mode = EDITING; return USED;
        case 'j': newTile(app->tiler, DOWN, app->lbufs->items[0]);
                  app->mode = EDITING; return USED;
        case 'k': newTile(app->tiler, UP, app->lbufs->items[0]);
                  app->mode = EDITING; return USED;
        case 'l': newTile(app->tiler, RIGHT, app->lbufs->items[0]);
                  app->mode = EDITING; return USED;
        default: shiftKeysLeft(app->cg, c->klen - 1); return RERUN;
        }

    case 'v':
        app->mode = CHHIGHLIGHT;
        tile->curs->vln = tile->curs->ln;
        tile->curs->vch = tile->curs->ch;
        setCursorSolidBar();
        return USED;

    case 'V':
        app->mode = LNHIGHLIGHT;
        tile->curs->vln = tile->curs->ln;
        tile->curs->vch = tile->curs->ch;
        setCursorSolidBar();
        return USED;

    case 'w':
        if (app->mode != CHHIGHLIGHT)
            return USED; // TODO
        mvFastRight(tile);
        mvFastLeft(tile);
        tile->curs->vln = tile->curs->ln;
        tile->curs->vch = tile->curs->ch;
        mvFastRight(tile);
        return USED;

    case 'x': rmNextCh(tile); return USED;

    case ' ': app->mode = TYPING; setCursorBar(); return USED;

    case '<': unindentLnFront(tile); return USED;
    case '>': indentLnFront(tile); return USED;

    case 0x1A: // CTRL+Z
        exitAltScreen();
        fflush(stdout);

        disableRaw();
        if (kill(0, SIGTSTP) != 0)
            return QUIT;
        enableRaw();

        enterAltScreen();
        clearPrevFrame(app->frame);
        return USED;

        default: shiftKeysLeft(app->cg, c->klen); return INCOMPLETE;
    }

    // no cmd was used
    return INCOMPLETE;
}

static void
freeApp(App *app)
{
    int i;

    for (i = 0; i < app->lbufs->len; i++) {
        freeBuf(app->lbufs->items[i]);
    }
    freeCmdGen(app->cg);
    freeLBuf(app->lbufs);
    freeFrame(app->frame);
    freeTiler(app->tiler);
    close(app->fd);

    free(app);
}

