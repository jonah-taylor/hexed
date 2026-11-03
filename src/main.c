#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>

#include "term.h"
#include "tile.h"
#include "tiler.h"
#include "geometry.h"

int
handleKey(Tiler* tiler, char ch)
{
    switch(ch) {
    case 'D':
        rmTile(tiler);
        break;
    case 'h':
        getSel(tiler)->cursor.x--;
        break;
    case 'H':
        selTileInCursorDir(tiler, LEFT);
        break;
    case 'j':
        getSel(tiler)->cursor.y++;
        break;
    case 'J':
        selTileInCursorDir(tiler, DOWN);
        break;
    case 'k':
        getSel(tiler)->cursor.y--;
        break;
    case 'K':
        selTileInCursorDir(tiler, UP);
        break;
    case 'l':
        getSel(tiler)->cursor.x++;
        break;
    case 'L':
        selTileInCursorDir(tiler, RIGHT);
        break;
    case 't':
        ch = getch();
        switch(ch) {
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
    case 'q':
        return 1;
    }
    return 0;
}

int
main(int argc, char *argv[])
{
    argc = argc;
    argv = argv;

    Tiler tiler;

    if (enableRaw()) {
        perror("raw mode");
        exit(1);
    }

    enterAltScreen();
    clearScreen();

    initTiler(&tiler);
    drawTiles(&tiler);
    fflush(stdout);

    // main loop

    for (;;) {
        if (handleKey(&tiler, getch())) break;

        clearScreen();
        drawTiles(&tiler);
        fflush(stdout);
    }

    deinitTiler(&tiler);
    exitAltScreen();
    disableRaw();
    return 0;
}

