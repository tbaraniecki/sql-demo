# SQL Performance Lab

> Understanding how databases execute queries — and where they fall apart at scale.

This repository is where I explore SQL performance on large datasets using benchmarks like TPC-H.

I treat this as a hands-on lab — not just writing queries, but understanding what the database is actually doing under the hood.

In practice, I focus on things like:
- how data is accessed (sequential vs random I/O)
- how joins behave at scale
- how execution plans change as data grows
- where and why performance starts to break down

Most of this comes from digging into real queries, checking execution plans, and trying to make sense of unexpected behavior.

## Structure

- `queries/` — raw benchmark queries
- `resolutions/` — analysis, experiments, and optimizations

## Resolutions

- [q06.sql - random vs sequential IO](resolutions/q06_resolution.md)
- [q03.sql - over-optimizing IO](resolutions/q03_resolution.md)

## Other

- [General thoughts](general-thoughts.md)
