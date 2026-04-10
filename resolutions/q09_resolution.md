Query

```
-- Q09: Product Type Profit Measure
SELECT
    nation,
    o_year,
    SUM(amount) AS sum_profit
FROM (
    SELECT
        n_name AS nation,
        EXTRACT(YEAR FROM o_orderdate) AS o_year,
        l_extendedprice * (1 - l_discount) - ps_supplycost * l_quantity AS amount
    FROM part
    JOIN lineitem ON p_partkey = l_partkey
    JOIN supplier ON l_suppkey = s_suppkey
    JOIN partsupp ON ps_suppkey = l_suppkey AND ps_partkey = l_partkey
    JOIN orders ON o_orderkey = l_orderkey
    JOIN nation ON s_nationkey = n_nationkey
    WHERE p_name LIKE '%green%'
) AS sub
GROUP BY nation, o_year
ORDER BY nation, o_year DESC;
```

Trigram index for %green%

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_part_name_trgm
ON part USING gin (p_name gin_trgm_ops);


add:
CREATE INDEX idx_lineitem_part_supp_order
ON lineitem (l_partkey, l_suppkey, l_orderkey);

- second explain analyze hit it.
-

### Resolution

The main cost in Q9 is not the final aggregation, but the repeated nested-loop access pattern in the middle of the plan.

PostgreSQL first filters `part` using a parallel sequential scan because `p_name LIKE '%green%'` is not selective in a way a regular B-tree can exploit. It then joins `part`, `partsupp`, `supplier`, and `nation` through hash joins, which is reasonable.

The expensive section begins when the plan switches to a nested loop into `lineitem`. PostgreSQL uses an index on `l_partkey`, but the join condition also depends on `l_suppkey`, so the second predicate is applied as a filter rather than as part of the index access path. This causes 86,900 index probes into `lineitem`, followed by 651,847 index probes into `orders`.

The planner’s choice is locally understandable, but it creates a globally expensive fan-out pattern. This query is a good example of planner limits in multi-join workloads: even when each individual step looks valid, repeated nested-loop probes can dominate total runtime.

A useful next experiment is a composite index on `lineitem (l_partkey, l_suppkey, l_orderkey)`, because it aligns better with the actual join predicates and may reduce the amount of filtered work after each probe.
