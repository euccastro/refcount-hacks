refcount-hacks
==============

Proof of concept: unlimited extents semantics with zero copy for C structs/unions/types in an unmodified [Gambit](http://gambitscheme.org).

This experiment uses release functions on foreign objects to manage the reference count of a "root" foreign object that is depended upon, directly or transitively, by others.

The challenge is that release functions are only passed the pointer that the foreign object points to.  There may be more than one foreign object with the same pointer and, in a naive approach, there may be more than one object depended upon with the same pointer.

Both challenges are overcome via the following scheme:
- We maintain a mapping[1] from the addresses pointed to by foreign objects to the addresses of the `___alloc_rc` entries that hold their memory.
- We *don't* store intermediate dependencies.  If A depends on B which in turn depends on R, we look up R in our mapping (under the B key), and store a dependency from A directly to R.  This is not (just) an optimization.  The problem becomes very hairy if you try and handle transitive dependencies in a naive way.
- Since there may be more than one such (X, R) pair, we keep a count of the occurrences.  We use that count to remove entries from our table (so we don't leak space there).  In turn, we adjust the reference count of the `___alloc_rc`ed root only when we add or remove such entries to or from the table.

To try: `make run`

Background:

https://github.com/feeley/gambit/pull/61

https://github.com/feeley/gambit/pull/60

https://github.com/feeley/gambit/pull/59

https://mercure.iro.umontreal.ca/pipermail/gambit-list/2013-December/007313.html

[1] A real hash table would be used in a production version.  In a first approach I used a Gambit table (as in `(make-table)`), but I don't know how to work with those from C code, and calling `c-define`d functions from release functions [seemed](https://mercure.iro.umontreal.ca/pipermail/gambit-list/2013-December/007346.html) to cause memory leaks.  So just to get something working quickly, I use a simple linked list.
