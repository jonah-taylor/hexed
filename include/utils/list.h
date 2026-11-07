#pragma once

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "utils/xmem.h"

#define INIT_LIST_CAP 8
#define DEF_LIST(TypeName, T, FuncSig) \
typedef struct TypeName TypeName; \
struct TypeName { \
    T *items; \
    size_t len; \
    size_t cap; \
}; \
\
static inline TypeName* \
init##TypeName() \
{ \
    TypeName *list = xmalloc(sizeof(TypeName)); \
    *list = (TypeName){ \
        .items = xmalloc(INIT_LIST_CAP * sizeof(T)), \
        .len = 0, \
        .cap = INIT_LIST_CAP, \
    }; \
\
    return list; \
} \
\
static inline void \
free##TypeName(TypeName *list) \
{ \
    free(list->items); \
    free(list); \
} \
\
static inline void \
FuncSig##Resz(TypeName *list, size_t nwsz) \
{ \
    size_t oldsz = list->len; \
\
    if (nwsz > list->cap) { \
        list->cap = nwsz; \
        list->items = xrealloc(list->items, &list->cap, sizeof(T)); \
    } \
\
    if (nwsz > oldsz) \
        memset(&list->items[oldsz], 0, (nwsz - oldsz) * sizeof(T)); \
\
    list->len = nwsz; \
} \
\
static inline void \
FuncSig##Push(TypeName *list, T elm) \
{ \
    if (list->len == list->cap) \
        list->items = xrealloc(list->items, &list->cap, sizeof(T)); \
    list->items[list->len++] = elm; \
} \
\
static inline T \
FuncSig##Pop(TypeName *list) \
{ \
    if (list->len == 0) return (T){0}; \
    return list->items[--list->len]; \
} \
\
static inline T \
FuncSig##Peek(TypeName *list) \
{ \
    if (list->len == 0) return (T){0}; \
    return list->items[list->len - 1]; \
} \
\
static inline void \
FuncSig##Ins(TypeName *list, size_t idx, T elm) \
{ \
    if (idx > list->len) return; \
    if (list->len == list->cap) \
        list->items = xrealloc(list->items, &list->cap, sizeof(T)); \
\
    memmove( \
        list->items + idx + 1, \
        list->items + idx, \
        (list->len - idx) * sizeof(T) \
    ); \
\
    list->items[idx] = elm; \
    list->len++; \
} \
\
static inline void \
FuncSig##Rm(TypeName *list, size_t idx) \
{ \
    if (list->len == 0 || idx >= list->len) return; \
    memmove( \
        list->items + idx, \
        list->items + idx + 1, \
        ((list->len - 1) - idx) * sizeof(T) \
    ); \
    list->len--; \
}

