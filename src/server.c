#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

#include "app.h"
#include "buf.h"
#include "utils/list.h"

DEF_LIST(LBuf, Buf*, lb)

int
startServer(int *fd, int *port)
{
    int flags;
    struct sockaddr_in addr;

    *fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (*fd < 0) {
        fprintf(stderr, "socket\n");
        return -1;
    }

    addr = (struct sockaddr_in){0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);

    for (*port = 8000; *port < 9000; (*port)++) {
        addr.sin_port = htons(*port);
        if (bind(*fd, (struct sockaddr *)&addr, sizeof(addr)) >= 0)
            break;
    }
    if (*port == 9000) {
        fprintf(stderr, "failed to bind to port 8000-8999\n");
        close(*fd);
        return -1;
    }

    flags = fcntl(*fd, F_GETFL, 0);
    fcntl(*fd, F_SETFL, flags | O_NONBLOCK);

    return 0;
}

void
flushServer(App *app)
{
    int n, i, is_dup;
    char buf_name[4096];

    for (;;) {
        n = recv(app->fd, buf_name, sizeof(buf_name) - 1, 0);
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                break;
            }
            if (errno == EINTR)
                continue;
            break;
        }
        if (n == 0) continue;
        buf_name[n] = '\0';

        is_dup = 0;
        for (i = 0; i < app->lbufs->len; i++) {
            if (strncmp(app->lbufs->items[i]->name,
                        buf_name, sizeof(buf_name)) == 0) {
                is_dup = 1;
                break;
            }
        }
        if (!is_dup) {
            lbPush(app->lbufs, initBuf(""));
            loadFile(app->lbufs->items[app->lbufs->len - 1], buf_name);
            app->refr_bufs = 1;
        }
    }
}

