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

static int is_dir(const char *path);
static void send_abspath(int fd, struct sockaddr_in dest,
        const char *cwd, const char *rel_path);

void
client(int argc, char *argv[])
{
    struct sockaddr_in dest;
    int fd, port, i;
    char cwd[4096];

    fd = socket(AF_INET, SOCK_DGRAM, 0);

    if (fd < 0) {
        fprintf(stderr, "socket");
        return;
    }

    for (i = 0; i < (int)strlen(argv[1]); i++) {
        if (!isdigit(argv[1][i])) {
            fprintf(stderr, "the first arg must be the dest port\n");
            close(fd);
            return;
        }
    }

    port = atoi(argv[1]);

    dest = (struct sockaddr_in){0};
    dest.sin_family = AF_INET;
    dest.sin_port = htons(port);
    if (inet_pton(AF_INET, "127.0.0.1", &dest.sin_addr) != 1) {
        fprintf(stderr, "invalid dest addr\n");
        close(fd);
        return;
    }

    if (getcwd(cwd, sizeof(cwd)) == 0) {
        fprintf(stderr, "cwd\n");
        close(fd);
        return;
    }

    if (cwd[strlen(cwd) - 1] != '\\')
    if (cwd[strlen(cwd) - 1] != '/')
        strcat(cwd, "/");

    for (i = 2; i < argc; i++) {
        send_abspath(fd, dest, cwd, argv[i]);
    }

    close(fd);
}

static void
send_abspath(int fd, struct sockaddr_in dest, const char *cwd, const char *rel_path)
{
    char abs_path[4096];
    int len, n;

    if (is_dir(rel_path)) {
        fprintf(stderr, "ignoring directory: %s\n", rel_path);
        return;
    }

    snprintf(abs_path, sizeof(abs_path), "%s%s", cwd, rel_path);
    len = strlen(abs_path);

    n = sendto(fd, abs_path, len, 0, (struct sockaddr *)&dest, sizeof(dest));

    if (n < 0) {
        fprintf(stderr, "%s: sendto failed\n", rel_path);
    }
    else if (n != len) {
        fprintf(stderr, "%s: datagram corrupted\n", rel_path);
    }
}

static int
is_dir(const char *path)
{
    struct stat st;
    if (stat(path, &st) != 0)
        return -1;
    if (S_ISDIR(st.st_mode))
        return 1;
    else
        return 0;
}
