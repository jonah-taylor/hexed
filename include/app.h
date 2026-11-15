#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <sys/ioctl.h>

typedef struct CmdGen CmdGen;
typedef struct LBuf LBuf;
typedef struct LLCh LLCh;
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
    Mode mode;
    int refr_bufs;
    int fd;
    int port;

    CmdGen *cg;
    Frame *frame;
    LBuf *lbufs;
    Tiler *tiler;
};
