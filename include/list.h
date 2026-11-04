#pragma once

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

typedef struct List List;
struct List {
    char *items;
    size_t elmsz;
    size_t len;
    size_t cap;
};

List *initList(size_t elmsz);
void freeList(List *list);

void lpush(List *list, void *elm);
void lpop(List *list);

void *lpeek(List *list);
void *lget(List *list, size_t idx);

void lins(List *list, size_t idx, void *elm);
void lrm(List *list, size_t idx);

