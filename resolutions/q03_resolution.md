# Q03

```
tpch=# explain (analyze,buffers)
SELECT
    l_orderkey,
    SUM(l_extendedprice * (1 - l_discount)) AS revenue,
    o_orderdate,
    o_shippriority
FROM customer
JOIN orders ON c_custkey = o_custkey
JOIN lineitem ON l_orderkey = o_orderkey
WHERE c_mktsegment = 'BUILDING'
  AND o_orderdate < DATE '1995-03-15'
  AND l_shipdate > DATE '1995-03-15'
GROUP BY l_orderkey, o_orderdate, o_shippriority
ORDER BY revenue DESC, o_orderdate
LIMIT 10;
                                                                                      QUERY PLAN                                                                 
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=375457.35..375457.37 rows=10 width=48) (actual time=296.502..297.314 rows=10.00 loops=1)
   Buffers: shared hit=1109560 read=131132
   ->  Sort  (cost=375457.35..377059.00 rows=640662 width=48) (actual time=296.500..297.312 rows=10.00 loops=1)
         Sort Key: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))) DESC, orders.o_orderdate
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=1109560 read=131132
         ->  GroupAggregate  (cost=269379.02..361612.87 rows=640662 width=48) (actual time=282.940..296.061 rows=23170.00 loops=1)
               Group Key: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority
               Buffers: shared hit=1109560 read=131132
               ->  Gather Merge  (cost=269379.02..343994.67 rows=640662 width=28) (actual time=282.932..286.758 rows=61420.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=1109560 read=131132
                     ->  Sort  (cost=268379.00..269046.35 rows=266942 width=28) (actual time=272.665..273.045 rows=20473.33 loops=3)
                           Sort Key: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority
                           Sort Method: quicksort  Memory: 1761kB
                           Buffers: shared hit=1109560 read=131132
                           Worker 0:  Sort Method: quicksort  Memory: 1702kB
                           Worker 1:  Sort Method: quicksort  Memory: 1722kB
                           ->  Nested Loop  (cost=9264.25..237931.79 rows=266942 width=28) (actual time=19.196..270.818 rows=20473.33 loops=3)
                                 Buffers: shared hit=1109516 read=131130
                                 ->  Parallel Hash Join  (cost=9263.69..81750.88 rows=124024 width=16) (actual time=18.933..117.992 rows=98139.67 loops=3)
                                       Hash Cond: (orders.o_custkey = customer.c_custkey)
                                       Buffers: shared read=62640
                                       ->  Parallel Seq Scan on orders  (cost=0.00..70883.41 rows=610956 width=24) (actual time=0.107..59.134 rows=485705.33 loops=3)
                                             Filter: (o_orderdate < '1995-03-15'::date)
                                             Rows Removed by Filter: 514295
                                             Buffers: shared read=55256
                                       ->  Parallel Hash  (cost=8946.50..8946.50 rows=25375 width=8) (actual time=18.729..18.729 rows=20119.67 loops=3)
                                             Buckets: 65536  Batches: 1  Memory Usage: 2912kB
                                             Buffers: shared read=7384
                                             ->  Parallel Seq Scan on customer  (cost=0.00..8946.50 rows=25375 width=8) (actual time=0.108..15.185 rows=20119.67 loops=3)
                                                   Filter: (c_mktsegment = 'BUILDING'::bpchar)
                                                   Rows Removed by Filter: 79880
                                                   Buffers: shared read=7384
                                 ->  Index Only Scan using idx_lineitem_order_ship_2 on lineitem  (cost=0.56..1.09 rows=17 width=20) (actual time=0.001..0.001 rows=0.21 loops=294419)
                                       Index Cond: ((l_orderkey = orders.o_orderkey) AND (l_shipdate > '1995-03-15'::date))
                                       Heap Fetches: 0
                                       Index Searches: 294419
                                       Buffers: shared hit=1109516 read=68490
 Planning:
   Buffers: shared hit=8 read=19
 Planning Time: 2.461 ms
 Execution Time: 297.383 ms
(44 rows)
```

### Resolution

I analyzed the execution plan from the bottom up.

The planner’s row estimates were off by roughly 20–30%, but not enough to justify calling the plan incorrect. `lineitem` is already accessed efficiently through an `Index Only Scan` with `Heap Fetches: 0`, so there is little direct improvement available there.

The main decision point is `orders`. PostgreSQL chooses a `Parallel Seq Scan` on `orders` and combines it with filtered `customer` rows through a `Parallel Hash Join`. I tested indexes on `o_orderdate` and compound variants for `orders`, but the original plan remained faster. The reason is that the `o_orderdate` predicate still matches a large portion of the table, so an index-driven path would likely introduce many heap accesses with worse locality than a parallel sequential scan.

The nested loop into `lineitem` is not inherently wrong here. The expensive part is the number of probes, not a poor access method, because the lookup itself is already index-only.

Tested different query shapes and alternative indexing strategies. In the end, PostgreSQL’s original plan won. For this data distribution, the planner correctly prefers a parallel scan plus hash join over forcing a more index-heavy strategy.
