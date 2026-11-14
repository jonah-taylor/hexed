#pragma once

typedef struct App App;

int startServer(int *fd, int *port);
void flushServer(App *app);
