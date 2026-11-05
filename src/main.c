#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>

#include "cursor.h"
#include "geometry.h"
#include "term.h"
#include "tile.h"
#include "tiler.h"

typedef enum {
    RESIZING,
    TYPING,
    EDITING,
} Mode;

int
handleKey(char key, Mode *mode, Tiler* tiler)
{
    switch(key) {

    case 'C':
        rotTilesCW(tiler);
        break;

    case 'D':
        rmSel(tiler);
        break;

    case 'h':
        if (*mode == RESIZING) {
            reszSel(tiler, LEFT, true);
            break;
        }
        getSel(tiler)->cursor->x--;
        break;

    case 'H':
        selTileInCursorDir(tiler, LEFT);
        break;

    case 'j':
        if (*mode == RESIZING) {
            reszSel(tiler, DOWN, true);
            break;
        }
        getSel(tiler)->cursor->y++;
        break;

    case 'J':
        selTileInCursorDir(tiler, DOWN);
        break;

    case 'k':
        if (*mode == RESIZING) {
            reszSel(tiler, UP, true);
            break;
        }
        getSel(tiler)->cursor->y--;
        break;

    case 'K':
        selTileInCursorDir(tiler, UP);
        break;

    case 'l':
        if (*mode == RESIZING) {
            reszSel(tiler, RIGHT, true);
            break;
        }
        getSel(tiler)->cursor->x++;
        break;

    case 'L':
        selTileInCursorDir(tiler, RIGHT);
        break;

    case 'q':
        key = getch();
        switch (key) {
        case 'q':
            return 1;
        }
        break;

    case 'R':
        *mode = (*mode == RESIZING) ? EDITING : RESIZING;
        break;

    case 'S':
        key = getch();
        switch(key) {
        case 'h':
            swapCursorDir(tiler, LEFT);
            break;
        case 'j':
            swapCursorDir(tiler, DOWN);
            break;
        case 'k':
            swapCursorDir(tiler, UP);
            break;
        case 'l':
            swapCursorDir(tiler, RIGHT);
            break;
        }
        break;

    case 't':
        key = getch();
        switch(key) {
        case 'h':
            newTile(tiler, LEFT);
            break;
        case 'j':
            newTile(tiler, DOWN);
            break;
        case 'k':
            newTile(tiler, UP);
            break;
        case 'l':
            newTile(tiler, RIGHT);
            break;
        }
        break;

    }

    return 0;
}

int
main(int argc, char *argv[])
{
    argc = argc;
    argv = argv;

    Tiler *tiler;
    Mode mode;

    if (enableRaw()) {
        perror("raw mode");
        exit(1);
    }

    enterAltScreen();
    clearScreen();

    tiler = initTiler();
    drawTiles(tiler);
    fflush(stdout);

    mode = EDITING;

    for (;;) {
        char key = getch();
        if (handleKey(key, &mode, tiler)) break;

        clearScreen();
        drawTiles(tiler);
        fflush(stdout);
    }

    freeTiler(tiler);
    exitAltScreen();
    disableRaw();
    return 0;
}

