#pragma once

typedef struct Cmd Cmd;
struct Cmd {
    int num;
    char keys[16];
    int klen;
};

typedef struct CmdGen CmdGen;
struct CmdGen {
    Cmd prev;
    Cmd curr;
};

CmdGen *initCmdGen();
void freeCmdGen(CmdGen *cg);

void getchForCmd(CmdGen *cg);
void shiftKeysLeft(CmdGen *cg, int i);
void usedCmd(CmdGen *cg);
