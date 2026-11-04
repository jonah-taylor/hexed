#include "list.h"

#include "utils/xmem.h"

#define INIT_LIST_CAP 8

List*
initList(size_t elmsz)
{
    List *list = xmalloc(sizeof(List));
    *list = (List){
        .items = xmalloc(INIT_LIST_CAP * elmsz),
        .elmsz = elmsz,
        .len = 0,
        .cap = INIT_LIST_CAP,
    };

    return list;
}

void
freeList(List *list)
{
    free(list->items);
    list->items = 0;
    free(list);
    list = 0;
}

void
lpush(List *list, void *elm)
{
    if (list->len == list->cap) {
        list->cap *= 2;
        list->items = xrealloc(list->items, list->cap * list->elmsz);
    }
    memcpy(list->items + list->elmsz * list->len, elm, list->elmsz);
    list->len++;
}

void
lpop(List *list)
{
    if (list->len > 0) list->len -= 1;
}

void*
lpeek(List *list)
{
    if (list->len == 0) return 0;
    return lget(list, list->len - 1);
}

void*
lget(List *list, size_t idx)
{
    if (idx >= list->len) return 0;
    return list->items + list->elmsz * idx;
}

void
lins(List *list, size_t idx, void *elm)
{
    if (idx > list->len) return;

    if (list->len == list->cap) {
        list->cap *= 2;
        list->items = xrealloc(list->items, list->cap * list->elmsz);
    }

    memmove(
        list->items + list->elmsz * (idx + 1),
        list->items + list->elmsz * idx,
        (list->len - idx) * list->elmsz
    );

    memcpy(list->items + list->elmsz * idx, elm, list->elmsz);
    list->len++;
}

void
lrm(List *list, size_t idx)
{
    if (list->len == 0 || idx >= list->len) return;
    memmove(
        list->items + list->elmsz * idx,
        list->items + list->elmsz * (idx + 1),
        ((list->len - 1) - idx) * list->elmsz
    );
    list->len--;
}

