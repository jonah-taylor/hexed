#include "geometry.h"
#include "term.h"

struct termios orig;
int is_raw;

void
clearScreen()
{
    printf("\x1b[2J");
    fflush(stdout);
}

int
getch()
{
    unsigned char ch;
    if(read(STDIN_FILENO, &ch, 1) != 1)
        return -1;

    return ch;
}

void
showCursor()
{
    printf("\x1b[?25h");
}

void
hideCursor()
{
    printf("\x1b[?25l");
}

void
setCursorLine()
{
    printf("\x1b[6 q");
}

void
setCursorBlock()
{
    printf("\x1b[1 q");
}

void
saveCursorPos()
{
    printf("\x1b[s");
}

void
loadCursorPos()
{
    printf("\x1b[u");
}

void
enterAltScreen()
{
    printf("\x1b[?1049h");
    fflush(stdout);
}

void
exitAltScreen()
{
    printf("\x1b[?1049l");
    fflush(stdout);
}

void
setColors(int fg, int bg)
{
    if (fg <= 0 || bg <= 0)
        printf("\x1b[0m");
    if (fg > 0)
        printf("\x1b[%dm", fg);
    if (bg > 0)
        printf("\x1b[%dm", fg);
}

void
moveCursorTo(int row, int col)
{
    printf("\x1b[%d;%dH", row + 1, col + 1);
}

void
drawStrAtLoc(int row, int col, const char *str)
{
    printf("\x1b[%d;%dH%s", row + 1, col + 1, str);
}

Tab
getTermSz()
{
    struct winsize ws;
    // TIO (terminal io) GC (get) WINSZ (window size)
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws)
            || ws.ws_col == 0
            || ws.ws_row == 0)
        return (Tab){0, 0};

    return (Tab){ws.ws_row, ws.ws_col};
}

void
disableRaw(void)
{
    if (!is_raw) return;

    // TC (terminal ctrl) S (set) A (attributes)
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig);
    is_raw = 0;
}

void
handleDeath(int sig)
{
    // resets colors, moves back to main screen, etc
    static const char seq[] = "\x1b[0m\x1b[?25h\x1b[0 q\x1b[?1049l";

    disableRaw();
    // keep it syncronous with a single seq
    write(STDOUT_FILENO, seq, sizeof seq - 1);

    signal(sig, SIG_DFL);
    raise(sig);
}

int
enableRaw()
{
    static int registered = 0;

    if (is_raw) return 0;
    if (tcgetattr(STDIN_FILENO, &orig) == -1)
        return -1;

    struct termios raw = orig;

    /*
        disable typical breaking,
        parity checking,
        stripping 8th bit,
        ctrl+s/q
    */
    raw.c_iflag &= ~(BRKINT | INPCK | ISTRIP | IXON);

    // disable transforming output characters like \n to \r\n
    raw.c_oflag &= ~(OPOST);

    // use 8 bit chars
    raw.c_cflag |= CS8;

    /*
        disable echo typing,
        input by lines (doesn't wait for enter/ reads each char),
        extra input processing ctrl+o/v for literal input,
        ctrl+c/z
    */
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);


    // no read timeout
    raw.c_cc[VTIME] = 0;
    // wait for minimum of 1 byte
    raw.c_cc[VMIN] = 1;

    // TC (terminal ctrl) S (set) A (attributes)
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1)
        return -1;

    is_raw = 1;

    if (!registered) {
        atexit(disableRaw);
        signal(SIGTERM, handleDeath);
        signal(SIGHUP, handleDeath);
        registered = 1;
    }
    return 0;
}

int
fixedFromPercX(int x)
{
    return x * getTermSz().cols / PERC_DENOM;
}

int
fixedFromPercY(int y)
{
    return y * getTermSz().rows / PERC_DENOM;
}

Rect
fixedFromPercRect(Rect rect)
{
    return (Rect){
        .x1 = fixedFromPercX(rect.x1),
        .y1 = fixedFromPercY(rect.y1),
        .x2 = fixedFromPercX(rect.x2),
        .y2 = fixedFromPercY(rect.y2),
    };
}

int
percFromFixedX(int x)
{
    Tab sz = getTermSz();
    if (sz.cols == 0) return 0;

    return x * PERC_DENOM / sz.cols;
}

int
percFromFixedY(int y)
{
    Tab sz = getTermSz();
    if (sz.rows == 0) return 0;
    return y * PERC_DENOM / sz.rows;
}
