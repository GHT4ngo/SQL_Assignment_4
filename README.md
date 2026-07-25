# SQL Query Performance Analysis

> This project has moved to
> [`sql-assignments/assignment-04-query-performance`](https://github.com/GHT4ngo/sql-assignments/tree/main/assignment-04-query-performance).
> This repository is retained as a read-only archive.

An educational SQL Server assignment comparing three ways to find the
highest-spending customer in `AdventureWorksDW2019`.

**Live dashboard:** [sql4.t4ngo.com](https://sql4.t4ngo.com)

## Assignment

The assignment asks for:

- the first and last name of the customer who spent the most
- several query solutions
- execution-plan, I/O, memory, CPU, and elapsed-time comparisons
- a reasoned choice of the most efficient solution

## Files

| File | Purpose |
| --- | --- |
| `SQL_2_Assignment_2_CL.sql` | Queries, benchmark loops, and index experiments |
| `SQL_2_Assignment_2_CL.xlsx` | Original recorded measurements |
| `SQL_2_Assignment_2_PDF.pdf` | Original Swedish report |
| `Execution-plans/*.sqlplan` | Saved SQL Server execution plans |

The spreadsheet, PDF, and execution plans are retained as the original
assignment evidence.

## Query approaches

### Query 1: direct join

Joins customers and sales before grouping:

```sql
SELECT TOP 1
    c.FirstName,
    c.LastName,
    SUM(f.SalesAmount) AS TotalSales
FROM dbo.DimCustomer AS c
JOIN dbo.FactInternetSales AS f
  ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerKey, c.FirstName, c.LastName
ORDER BY TotalSales DESC, c.CustomerKey;
```

### Query 2: CTE and subquery

Aggregates sales first and returns only the customer name. It used the smallest
memory grant in the recorded plans, but it does not return the sales total.

### Query 3: CTE and join

Aggregates sales in a CTE, joins the result to the customer table, and returns
the customer name and sales total.

## Recorded findings

The saved measurements show:

- similar elapsed times for the three query forms
- a lower memory grant for Query 2 in the original plans
- fewer logical reads after adding a covering nonclustered index
- the strongest aggregation performance from the columnstore experiment

These results describe this database, SQL Server version, data volume, cache
state, and test environment. They should not be treated as universal rules.

Query 2 is a good choice when only the customer identity is required. Query 1
or Query 3 is more useful when the total sales amount must also be returned.

## Measurement notes

`SET STATISTICS IO ON` reports page reads. `SET STATISTICS TIME ON` reports CPU
and elapsed time in the SSMS Messages output.

The repeated benchmark in the SQL file now reads CPU time from the current SQL
session. The original spreadsheet was produced by an older version that used
the server-wide `@@CPU_BUSY` counter. Its CPU values are therefore historical
observations, not precise per-query measurements. The original evidence files
remain unchanged for transparency.

The benchmark removes the five fastest and five slowest elapsed-time results
before calculating averages. This is a simple classroom comparison, not a
production-grade performance study.

## Running the project

### Requirements

- SQL Server with `AdventureWorksDW2019`
- SQL Server Management Studio or another client supporting `GO`
- permission to inspect plans and create test tables and indexes

### Recommended order

Run the SQL file section by section:

1. Enable statistics and run the three queries.
2. Inspect the actual execution plans.
3. Create `RawFactInternetSalesBig` only in a dedicated test database.
4. Run the repeated benchmarks.
5. Set `@IndexTest` to `NONCLUSTERED` or `COLUMNSTORE`.
6. Rerun the queries, save the measurements, and remove the test index.
7. Drop the large test table when it is no longer needed.

Do not run the entire file blindly.

## Important safety notes

`DBCC DROPCLEANBUFFERS` and `DBCC FREEPROCCACHE` affect the entire SQL Server
instance. Use them only in an isolated test environment. Never use them on a
shared production server.

`RawFactInternetSalesBig` duplicates the fact table 100 times and can consume
considerable disk and log space.

Index creation and columnstore experiments can also use significant CPU, disk,
memory, and transaction-log capacity.

## Index experiments

The assignment compares:

- a covering nonclustered index on `CustomerKey` including `SalesAmount`
- a nonclustered columnstore index on `CustomerKey` and `SalesAmount`

The covering index reduced logical reads in the recorded rowstore tests.
Columnstore performed well for this aggregation workload, but its suitability
depends on the wider read/write workload and cannot be decided from one query.

## Execution plans

Open `.sqlplan` files in SQL Server Management Studio:

```text
File → Open → File
```

The saved plans allow the query shapes, memory grants, scans, seeks, and
parallel operators to be reviewed without rerunning the experiment.

## Scope

This repository presents an educational comparison. It does not attempt to be a
general benchmarking framework or a production index recommendation system.

## Author

Christofer Lindholm — Data Engineering DE25.
