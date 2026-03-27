# Query drilldown

```


```

Query gets about 230k rows from 12mln in table.

Query approaches:
* no indexes
* single column indexes
* forced use of index
* compound index
* compound index (filtering) with includes field of (from select)

### No indexes
Planner chooses paralell sequential disk scan.
99% of time spend is in reading.

## Single column indexes
Planner still chooses to use sequential scan. 

## Compound index
Planner still chooses to use sequential scan.

## Forced use index.
Query is 2 times slower. Index + random disk access.

## Compound index with includes.
Everything is readable from index. 
Planner uses index scan only.

```
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=46332.33..46332.34 rows=1 width=32) (actual time=100.560..100.561 rows=1.00 loops=1)
   Buffers: shared hit=142226
   ->  Index Only Scan using idx_lineitem_l_quantity_4 on lineitem  (cost=0.56..45153.30 rows=235806 width=12) (actual time=0.090..80.869 rows=227679.00 loops=1)
         Index Cond: ((l_shipdate >= '1994-01-01'::date) AND (l_shipdate < '1995-01-01'::date) AND (l_quantity < '24'::numeric) AND (l_discount >= 0.05) AND (l_discount <= 0.07))
         Heap Fetches: 0
         Index Searches: 582
         Buffers: shared hit=142226
 Planning:
   Buffers: shared hit=1
 Planning Time: 0.216 ms
 Execution Time: 100.593 ms
(11 rows)
```
