
Db file layout
Header takes 128 bytes (but doesn't need to)
Data fills the rest of the first 4kb block
Tuples don't span across 4kb boundaries
+---------------------------+
|                           |
|      Header               |
+---------------------------+
|      page 1               |
+---------------------------+
|                           |
|      page 2               |
|                           |
+---------------------------+
|                           |
|      ...                  |
|                           |
+---------------------------+
|                           |
|      page n               |
|                           |
+---------------------------+
