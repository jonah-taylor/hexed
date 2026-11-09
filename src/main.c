#include "app.h"
#include "buf.h"
#include "cursor.h"
#include "frame.h"
#include "geometry.h"
#include "term.h"
#include "tile.h"
#include "tiler.h"
#include "utils/list.h"
#include "utils/xmem.h"

DEF_LIST(LBuf, Buf*, lb)

static void freeApp(App *app);
static int handleKey(char key, App *app);

int
main(int argc, char *argv[])
{
    App *app;

    argc = argc;
    argv = argv;

    app = xmalloc(sizeof(*app));
    *app = (App){
        .lbufs = initLBuf(),
        .frame = initFrame(),
        .mode = EDITING,
        .tiler = 0,
    };

    lbPush(app->lbufs, initBuf("empty"));
    loadFile(app->lbufs->items[0], "src/main.c");

    app->tiler = initTiler(app->lbufs->items[0]);

    if (enableRaw()) {
        perror("raw mode");
        exit(1);
    }

    enterAltScreen();
    clearScreen();

    reszFrame(app->frame, getTermSz());
    drawTilesOnFrame(app->tiler, app->frame, app->mode);
    drawFrame(app->frame);
    fflush(stdout);

    for (;;) {
        char key = getch();
        if (handleKey(key, app)) break;

        reszFrame(app->frame, getTermSz());
        drawTilesOnFrame(app->tiler, app->frame, app->mode);

        drawFrame(app->frame);
        fflush(stdout);
    }

    freeApp(app);

    exitAltScreen();
    disableRaw();
    return 0;
}

static void
freeApp(App *app)
{
    size_t i;

    for (i = 0; i < app->lbufs->len; i++) {
        freeBuf(app->lbufs->items[i]);
    }
    freeLBuf(app->lbufs);
    freeFrame(app->frame);
    freeTiler(app->tiler);

    free(app);
}

static int
handleKey(char key, App *app)
{
    switch(key) {

    case 'C':
        rotTilesCW(app->tiler);
        break;

    case 'D':
        rmSel(app->tiler);
        break;

    case 'h':
        if (app->mode == RESIZING) {
            reszSel(app->tiler, LEFT, true);
            break;
        }
        getSel(app->tiler)->curs.x--;
        break;

    case 'H':
        selTileInCursorDir(app->tiler, LEFT);
        break;

    case 'j':
        if (app->mode == RESIZING) {
            reszSel(app->tiler, DOWN, true);
            break;
        }
        getSel(app->tiler)->curs.y++;
        break;

    case 'J':
        selTileInCursorDir(app->tiler, DOWN);
        break;

    case 'k':
        if (app->mode == RESIZING) {
            reszSel(app->tiler, UP, true);
            break;
        }
        getSel(app->tiler)->curs.y--;
        break;

    case 'K':
        selTileInCursorDir(app->tiler, UP);
        break;

    case 'l':
        if (app->mode == RESIZING) {
            reszSel(app->tiler, RIGHT, true);
            break;
        }
        getSel(app->tiler)->curs.x++;
        break;

    case 'L':
        selTileInCursorDir(app->tiler, RIGHT);
        break;

    case 'q':
        key = getch();
        switch (key) {
        case 'q':
            return 1;
        }
        break;

    case 'R':
        app->mode = (app->mode == RESIZING) ? EDITING : RESIZING;
        break;

    case 'S':
        key = getch();
        switch(key) {
        case 'h':
            swapCursorDir(app->tiler, LEFT);
            break;
        case 'j':
            swapCursorDir(app->tiler, DOWN);
            break;
        case 'k':
            swapCursorDir(app->tiler, UP);
            break;
        case 'l':
            swapCursorDir(app->tiler, RIGHT);
            break;
        }
        break;

    case 't':
        key = getch();
        switch(key) {
        case 'h':
            newTile(app->tiler, LEFT, app->lbufs->items[0]);
            break;
        case 'j':
            newTile(app->tiler, DOWN, app->lbufs->items[0]);
            break;
        case 'k':
            newTile(app->tiler, UP, app->lbufs->items[0]);
            break;
        case 'l':
            newTile(app->tiler, RIGHT, app->lbufs->items[0]);
            break;
        }
        break;

    }

    return 0;
}
