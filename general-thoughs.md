Thoughts on query optimization:

### Query that runs once a day

Drawing conclusions from a query that runs ance a day. A single execution can be misleading. It should be observed over long period to see what actually stays in buffer and what optimization actually held up.


### Optimizations
Cases:
- not selective filter
- select want to have data from many columns

Postgresql might still choose to do sequential scan, because once it filters, but later it need row fetch data.

Over optimizing might not be any good :)
