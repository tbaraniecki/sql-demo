


Dedicated index for many dates:
```
CREATE INDEX idx_lineitem_shipmode_conditions
ON lineitem (l_receiptdate, l_shipmode, l_orderkey)
WHERE l_commitdate < l_receiptdate
  AND l_shipdate < l_commitdate;
```

Explain Analyze:
```
Finalize GroupAggregate  (cost=128120.72..128122.89 rows=7 width=27) (actual time=328.091..329.719 rows=2.00 loops=1)
  Group Key: lineitem.l_shipmode
  Buffers: shared hit=28913 read=64464 written=13
  ->  Gather Merge  (cost=128120.72..128122.70 rows=17 width=27) (actual time=328.087..329.714 rows=6.00 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        Buffers: shared hit=28913 read=64464 written=13
        ->  Sort  (cost=127120.69..127120.71 rows=7 width=27) (actual time=318.819..318.820 rows=2.00 loops=3)
              Sort Key: lineitem.l_shipmode
              Sort Method: quicksort  Memory: 25kB
              Buffers: shared hit=28913 read=64464 written=13
              Worker 0:  Sort Method: quicksort  Memory: 25kB
              Worker 1:  Sort Method: quicksort  Memory: 25kB
              ->  Partial HashAggregate  (cost=127120.53..127120.60 rows=7 width=27) (actual time=318.754..318.755 rows=2.00 loops=3)
                    Group Key: lineitem.l_shipmode
                    Batches: 1  Memory Usage: 32kB
                    Buffers: shared hit=28899 read=64464 written=13
                    Worker 0:  Batches: 1  Memory Usage: 32kB
                    Worker 1:  Batches: 1  Memory Usage: 32kB
                    ->  Merge Join  (cost=7369.32..126694.17 rows=24363 width=27) (actual time=55.115..315.053 rows=20658.67 loops=3)
                          Merge Cond: (orders.o_orderkey = lineitem.l_orderkey)
                          Buffers: shared hit=28899 read=64464 written=13
                          ->  Parallel Index Scan using orders_pkey on orders  (cost=0.43..115671.71 rows=1250000 width=24) (actual time=0.214..226.696 rows=999991.00 loops=3)
                                Index Searches: 1
                                Buffers: shared hit=8041 read=63424 written=13
                          ->  Sort  (cost=7366.04..7512.22 rows=58471 width=19) (actual time=54.840..56.647 rows=61970.33 loops=3)
                                Sort Key: lineitem.l_orderkey
                                Sort Method: quicksort  Memory: 3957kB
                                Buffers: shared hit=20858 read=1040
                                Worker 0:  Sort Method: quicksort  Memory: 3957kB
                                Worker 1:  Sort Method: quicksort  Memory: 3957kB
                                ->  Index Only Scan using idx_lineitem_shipmode_conditions on lineitem  (cost=0.43..2736.47 rows=58471 width=19) (actual time=0.421..45.087 rows=61976.00 loops=3)
                                      Index Cond: ((l_receiptdate >= '1994-01-01'::date) AND (l_receiptdate < '1995-01-01'::date) AND (l_shipmode = ANY ('{MAIL,SHIP}'::bpchar[])))
                                      Heap Fetches: 0
                                      Index Searches: 600
                                      Buffers: shared hit=20850 read=1038
Planning:
  Buffers: shared hit=35 read=13
Planning Time: 4.188 ms
Execution Time: 330.188 ms
(40 rows)
```

And next. Dedicated partial index.
```
CREATE INDEX idx_lineitem_q12
ON lineitem (l_orderkey, l_shipmode)
WHERE l_commitdate < l_receiptdate
  AND l_shipdate < l_commitdate
  AND l_receiptdate >= '1994-01-01'
  AND l_receiptdate < '1995-01-01';
```

and explain analyze.
```
Finalize GroupAggregate  (cost=88582.07..88584.25 rows=7 width=27) (actual time=154.269..155.298 rows=2.00 loops=1)
  Group Key: lineitem.l_shipmode
  Buffers: shared hit=68377 read=56780 written=13
  ->  Gather Merge  (cost=88582.07..88584.05 rows=17 width=27) (actual time=154.264..155.293 rows=6.00 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        Buffers: shared hit=68377 read=56780 written=13
        ->  Sort  (cost=87582.05..87582.07 rows=7 width=27) (actual time=144.751..144.752 rows=2.00 loops=3)
              Sort Key: lineitem.l_shipmode
              Sort Method: quicksort  Memory: 25kB
              Buffers: shared hit=68377 read=56780 written=13
              Worker 0:  Sort Method: quicksort  Memory: 25kB
              Worker 1:  Sort Method: quicksort  Memory: 25kB
              ->  Partial HashAggregate  (cost=87581.88..87581.95 rows=7 width=27) (actual time=144.715..144.715 rows=2.00 loops=3)
                    Group Key: lineitem.l_shipmode
                    Batches: 1  Memory Usage: 32kB
                    Buffers: shared hit=68363 read=56780 written=13
                    Worker 0:  Batches: 1  Memory Usage: 32kB
                    Worker 1:  Batches: 1  Memory Usage: 32kB
                    ->  Nested Loop  (cost=0.42..87155.53 rows=24363 width=27) (actual time=0.820..140.544 rows=20658.67 loops=3)
                          Buffers: shared hit=68363 read=56780 written=13
                          ->  Parallel Index Only Scan using idx_lineitem_q12 on lineitem  (cost=0.42..5752.23 rows=24363 width=19) (actual time=0.564..14.566 rows=20658.67 loops=3)
                                Index Cond: (l_shipmode = ANY ('{MAIL,SHIP}'::bpchar[]))
                                Heap Fetches: 0
                                Index Searches: 1
                                Buffers: shared hit=88 read=1067
                          ->  Index Scan using idx_orders_hash on orders  (cost=0.00..3.34 rows=1 width=24) (actual time=0.006..0.006 rows=1.00 loops=61976)
                                Index Cond: (o_orderkey = lineitem.l_orderkey)
                                Rows Removed by Index Recheck: 0
                                Index Searches: 61976
                                Buffers: shared hit=68275 read=55713 written=13
Planning:
  Buffers: shared hit=33 read=17
Planning Time: 3.707 ms
Execution Time: 155.373 ms
(35 rows)
```

Difference in behaviour:

- ogólny index    → wejdź → filtruj → filtruj → filtruj → wynik
- partial index   → wejdź → wynik

Trying `SET enable_nestloop = off;`
makes query runs 220ms instead of 150ms.
