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
    loadFile(app->lbufs->items[0], "test.txt");

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
    updateCursor(getSel(app->tiler));
    fflush(stdout);

    for (;;) {
        char key = getch();
        if (handleKey(key, app)) break;

        reszFrame(app->frame, getTermSz());
        drawTilesOnFrame(app->tiler, app->frame, app->mode);

        drawFrame(app->frame);
        updateCursor(getSel(app->tiler));
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
    int i;

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
    Tile *curr_tile;
    char str[5];

    curr_tile = getSel(app->tiler);

    // mode agnostic
    switch (key) {
    case '\t':
        if (app->mode == EDITING) {
            app->mode = TYPING;
            setCursorLine();
        }
        else {
            app->mode = EDITING;
            setCursorBlock();
        }
        return 0;
    case '\x08': // backspace
    case '\x7f':
        typeBksp(curr_tile);
        return 0;
    case '\r':
    case '\n':
        typeEnter(curr_tile);
        return 0;
    case '\x1b': // arrow keys
        if (read(STDIN_FILENO, &key, 1) != 1 || key != '[')
            return 0;
        if (read(STDIN_FILENO, &key, 1) != 1)
            return 0;
        switch (key) {
        case 'A': mvUp(curr_tile); return 0;
        case 'B': mvDown(curr_tile); return 0;
        case 'C': mvRight(curr_tile); return 0;
        case 'D': mvLeft(curr_tile); return 0;
        case '1':
            if (read(STDIN_FILENO, &str, 5) != 5)
                return 0;
            if (strncmp(str, "05;5u", 5) == 0) {
                typeTab(curr_tile);
                return 0;
            }
        }
    }

    // typing
    if (app->mode == TYPING) {
        typeChar(curr_tile, key);
        return 0;
    }

    // editting/resizing
    switch(key) {

    case 'C': rotTilesCW(app->tiler); break;
    case 'd':
        key = getch();
        switch (key) {
        case 'd': rmLn(curr_tile); break;
        case 'h': rmLnBeforeCurs(curr_tile); break;
        case 'l': rmLnAfterCurs(curr_tile); break;
        case 'j': rmLnBelow(curr_tile); break;
        case 'k': rmLnAbove(curr_tile); break;
        }
        break;
    case 'D': rmSel(app->tiler); break;

    case 'h':
        if (app->mode == RESIZING)
            reszSel(app->tiler, LEFT, true);
        else
            mvLeft(curr_tile);
        break;

    case 'H': selTileInCursorDir(app->tiler, LEFT); break;
    case 'i': mvFastLeft(curr_tile); break;
    case 'I': mvFullLeft(curr_tile); break;

    case 'j':
        if (app->mode == RESIZING)
            reszSel(app->tiler, DOWN, true);
        else
            mvDown(curr_tile);
        break;

    case 'J': selTileInCursorDir(app->tiler, DOWN); break;

    case 'k':
        if (app->mode == RESIZING)
            reszSel(app->tiler, UP, true);
        else
            mvUp(curr_tile);
        break;

    case 'K': selTileInCursorDir(app->tiler, UP); break;

    case 'l':
        if (app->mode == RESIZING)
            reszSel(app->tiler, RIGHT, true);
        else
            mvRight(curr_tile);
        break;

    case 'L': selTileInCursorDir(app->tiler, RIGHT); break;
    case 'm': jmpDown(curr_tile, 10); break;
    case 'M': jmpUp(curr_tile, 10); break;
    case 'n': newLnBelow(curr_tile); break;
    case 'N': newLnAbove(curr_tile); break;
    case 'o': mvFastRight(curr_tile); break;
    case 'O': mvFullRight(curr_tile); break;

    case 'q':
        key = getch();
        if (key == 'q')
            return 1;
        break;

    case 'R': app->mode = (app->mode == RESIZING) ? EDITING : RESIZING; break;

    case 'S':
        key = getch();
        switch(key) {
        case 'h': swapCursorDir(app->tiler, LEFT); break;
        case 'j': swapCursorDir(app->tiler, DOWN); break;
        case 'k': swapCursorDir(app->tiler, UP); break;
        case 'l': swapCursorDir(app->tiler, RIGHT); break;
        }
        break;

    case 't':
        key = getch();
        switch(key) {
        case 'h': newTile(app->tiler, LEFT, app->lbufs->items[0]); break;
        case 'j': newTile(app->tiler, DOWN, app->lbufs->items[0]); break;
        case 'k': newTile(app->tiler, UP, app->lbufs->items[0]); break;
        case 'l': newTile(app->tiler, RIGHT, app->lbufs->items[0]); break;
        }
        break;

    case 'x': rmNextCh(curr_tile); break;

    case '<': unindentLnFront(curr_tile); break;
    case '>': indentLnFront(curr_tile); break;
    }

    return 0;
}
