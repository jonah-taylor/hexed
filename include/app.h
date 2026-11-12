#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <sys/ioctl.h>

typedef struct LBuf LBuf;
typedef struct Frame Frame;
typedef struct Tiler Tiler;

enum Mode : int {
    RESIZING,
    TYPING,
    EDITING,
};
typedef enum Mode Mode;

typedef struct App App;
struct App {
    LBuf *lbufs;
    Frame *frame;
    Mode mode;
    Tiler *tiler;
};
