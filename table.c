#include <malloc.h>
#include "table.h"

table_entry *table_head = 0;

extern void table_put(void *key, void *root) {
    table_entry *e;

    e = table_get(key);
    if (!e) {
        e = (table_entry*)malloc(sizeof(table_entry));
        e->next = table_head;
        table_head = e;
    }
    e->key = key;
    e->root = root;
    e->refcount = 1;
}

extern table_entry* table_get(void *key) {
    table_entry *e;
    for (e=table_head; e && e->key != key; e=e->next)
        ;
    return e;
}

extern void table_remove(void *key) {
    table_entry *e;
    table_entry *prev;

    for (e=table_head, prev=0; e; prev=e, e=e->next) {
        if (e->key == key) {
            if (prev)
                prev->next = e->next;
            else
                table_head = e->next;
            free(e);
            break;
        }
    }
}

/* debug */
void table_print(void) {
    table_entry *e;

    printf("Table is:\n");
    for (e=table_head; e; e=e->next) {
        printf("    dependent: %p  root: %p  refcount: %d\n", e->key,
                                                              e->root,
                                                              e->refcount);
    }
}
