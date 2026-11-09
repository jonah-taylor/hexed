#pragma once

#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

typedef struct Rect Rect;
typedef struct Tab Tab;

extern struct termios orig;
extern int is_raw;

#define PERC_DENOM 1024
#define INC 32

void clearScreen();

int getch();

void showCursor();
void hideCursor();

void setCursorLine();
void setCursorBlock();

void saveCursorPos();
void loadCursorPos();

void enterAltScreen();
void exitAltScreen();

void setColors(int fg, int bg);
void moveCursorTo(size_t row, size_t col);
void drawStrAtLoc(size_t row, size_t col, const char *str);

Tab getTermSz();

void disableRaw(void);
int enableRaw(void);

int fixedFromPercX(int x);
int fixedFromPercY(int y);
Rect fixedFromPercRect(Rect rect);

int percFromFixedX(int x);
int percFromFixedY(int y);
