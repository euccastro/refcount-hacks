all: test-dual-refcount

test-dual-refcount.c: test-dual-refcount.scm
	gsc -debug -c test-dual-refcount.scm

test-dual-refcount: test-dual-refcount.c table.c table.h
	gsc -exe -cc-options -g -o test-dual-refcount table.c test-dual-refcount.c 

run: test-dual-refcount
	./test-dual-refcount
