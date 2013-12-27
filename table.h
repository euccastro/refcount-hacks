typedef struct table_entry_t {
    void* key;
    void* root;
    int refcount;
    struct table_entry_t *next;
} table_entry;

void table_put(void *key, void *root);
table_entry* table_get(void *key);
void table_remove(void *key);
void table_print(void);
