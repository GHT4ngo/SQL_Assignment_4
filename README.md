# SQL_2_Assignment – Query Performance Analysis

**Author:** Christofer Lindholm  
**Course:** DE25  
**Date:** 2025-11-16

---

## Overview

This project analyzes and compares the performance of three different SQL query approaches to identify the top-spending customer in the AdventureWorksDW2019 database. The analysis includes comprehensive performance testing, execution plan analysis, and indexing optimization strategies.

**Database:** AdventureWorksDW2019  
**Tables Used:** 
- `DimCustomer`
- `FactInternetSales`

**Live Demo:** [View Interactive Dashboard](https://sql2assignment2.lovable.app)

---

## Assignment Objective

Retrieve information about the customer who has spent the most money:
- Customer's first name and last name (required)
- Total amount spent (optional)

Compare multiple query approaches to determine the most efficient solution based on:
- Execution plans
- I/O statistics (logical reads, physical reads)
- Memory usage (Memory Granted)
- CPU consumption

---

## Project Structure
```
SQL_2_Assignment_2/
├── README.md                                    # This file
├── sql/
│   └── SQL_2_Assignment_2_CL.sql               # All queries and tests
├── data/
│   └── SQL_2_Assignment_2_CL.xlsx              # Performance metrics
├── docs/
│   └── SQL_2_Assignment_2_PDF.pdf              # Full analysis report (Swedish)
└── execution-plans/                             # .sqlplan files (15 total)
    ├── original/                               # Initial tests on FactInternetSales
    │   ├── Query1.sqlplan
    │   ├── Query2.sqlplan
    │   └── Query3.sqlplan
    ├── big-table/                              # Tests on RawFactInternetSalesBig
    │   ├── Query1_BigTable.sqlplan
    │   ├── Query2_BigTable.sqlplan
    │   └── Query3_BigTable.sqlplan
    ├── with-index/                             # Tests with nonclustered index
    │   ├── Query1_With_Index.sqlplan
    │   ├── Query2_With_Index.sqlplan
    │   ├── Query3_With_Index.sqlplan
    │   ├── Query1_BigTable_With_Index.sqlplan
    │   ├── Query2_BigTable_With_Index.sqlplan
    │   └── Query3_BigTable_With_Index.sqlplan
    └── with-columnstore/                       # Tests with columnstore index
        ├── Query1_With_Columnstore_Index.sqlplan
        ├── Query2_With_Columnstore_Index.sqlplan
        └── Query3_With_Columnstore_Index.sqlplan
```

---

## Three Query Approaches

### Query 1: JOIN-Based Approach
**Method:** Direct JOIN with GROUP BY aggregation
```sql
SELECT TOP 1
    c.FirstName
    ,c.LastName
    ,SUM(f.SalesAmount) AS TotalSales
FROM dbo.DimCustomer AS c
JOIN dbo.FactInternetSales AS f
    ON f.CustomerKey = c.CustomerKey
GROUP BY
    c.CustomerKey
    ,c.FirstName
    ,c.LastName
ORDER BY
    TotalSales DESC
```

**Characteristics:**
- Returns first name, last name, and total sales amount
- Traditional JOIN approach
- Memory Granted: 5,648 KB

---

### Query 2: CTE with Subquery (No Sales Amount)
**Method:** CTE for aggregation, subquery for filtering
```sql
WITH x AS (
    SELECT 
        CustomerKey
        ,SUM(SalesAmount) AS TotalSales
    FROM dbo.FactInternetSales
    GROUP BY CustomerKey
) 
SELECT TOP 1
    c.FirstName
    ,c.LastName 
FROM dbo.DimCustomer AS c
WHERE CustomerKey IN (
    SELECT TOP 1 
        CustomerKey 
    FROM x 
    ORDER BY TotalSales DESC
);
```

**Characteristics:**
- Returns ONLY first name and last name (no sales amount)
- Most memory-efficient approach
- Memory Granted: 3,016 KB (47% less than Query 1 & 3)

---

### Query 3: CTE with JOIN (Full Information)
**Method:** CTE for aggregation, JOIN to retrieve customer details
```sql
WITH x AS (
    SELECT 
        CustomerKey
        ,SUM(SalesAmount) AS TotalSales
    FROM dbo.FactInternetSales
    GROUP BY CustomerKey
) 
SELECT TOP 1
    c.FirstName 
    ,c.LastName
    ,x.TotalSales
FROM dbo.DimCustomer AS c
JOIN x ON c.CustomerKey = x.CustomerKey
ORDER BY x.TotalSales DESC;
```

**Characteristics:**
- Returns first name, last name, and total sales amount
- CTE-based approach with JOIN
- Memory Granted: 5,648 KB

---

## Testing Methodology

### Phase 1: Initial Performance Testing
**Target:** Original `FactInternetSales` table

**Process:**
1. Clear cache and execution plans before each query
```sql
   DBCC DROPCLEANBUFFERS;
   DBCC FREEPROCCACHE;
```
2. Enable statistics tracking
```sql
   SET STATISTICS IO ON;
   SET STATISTICS TIME ON;
```
3. Execute each query once
4. Capture execution plans (.sqlplan files)
5. Record metrics using [statisticsparser.com](https://statisticsparser.com/)

**Key Finding:**
- All three queries had similar execution times
- Query 2 showed significantly lower memory consumption (3,016 KB vs 5,648 KB)

---

### Phase 2: Large-Scale Testing

**Setup:**
Created test table `RawFactInternetSalesBig` containing 100x the original data:
```sql
SELECT f.*
INTO AdventureWorksDW2019.dbo.RawFactInternetSalesBig
FROM AdventureWorksDW2019.dbo.FactInternetSales AS f
CROSS JOIN (
    SELECT TOP (100) 1 AS n
    FROM AdventureWorksDW2019.dbo.FactInternetSales
) AS x;

-- Create clustered index
CREATE CLUSTERED INDEX idx_RawFactInternetSalesBig_SalesOrderNumber
ON AdventureWorksDW2019.dbo.RawFactInternetSalesBig (SalesOrderNumber);
```

**Testing Process:**
1. Each query executed 100 times against the large table
2. CPU time and elapsed time measured for each run
3. Statistical analysis:
   - Excluded top 5 and bottom 5 runs (outliers)
   - Calculated averages from middle 90 runs
   - Captured min/max values

**Key Finding:**
- All three queries performed very similarly on repeated execution
- SQL Server optimizer generates comparable execution plans
- Syntax differences had minimal impact on execution time

---

### Phase 3: Index Optimization Testing

#### Test 3A: Nonclustered Index

**Index Creation:**
```sql
-- On FactInternetSales
CREATE NONCLUSTERED INDEX idx_FactInternetSales_CustomerKey_SalesAmount
ON dbo.FactInternetSales (CustomerKey)
INCLUDE (SalesAmount);

-- On RawFactInternetSalesBig
CREATE NONCLUSTERED INDEX idx_RawFactInternetSalesBig_CustomerKey_SalesAmount
ON dbo.RawFactInternetSalesBig (CustomerKey)
INCLUDE (SalesAmount);
```

**Results:**
- Dramatically reduced logical reads
  - Query 2: 1,252 → 288 logical reads (77% reduction)
- Slightly increased CPU time
- Demonstrates that fewer logical reads ≠ lower CPU usage

---

#### Test 3B: Nonclustered Columnstore Index

**Index Creation:**
```sql
-- On FactInternetSales
CREATE NONCLUSTERED COLUMNSTORE INDEX nccidx_FactInternetSales_CustomerKey_SalesAmount
ON dbo.FactInternetSales (CustomerKey, SalesAmount);

-- On RawFactInternetSalesBig
CREATE NONCLUSTERED COLUMNSTORE INDEX nccidx_RawFactInternetSalesBig_CustomerKey_SalesAmount
ON dbo.RawFactInternetSalesBig (CustomerKey, SalesAmount);
```

**Results:**
- Best performance for large-scale aggregations
- Logical reads reduced to nearly zero
- Significant reduction in average execution time over 100 runs
- **Trade-off:** Reduced write performance (not suitable for OLTP systems)

---

## Key Findings

### Performance Comparison Summary

| Metric | Query 1 (JOIN) | Query 2 (CTE + Subquery) | Query 3 (CTE + JOIN) |
|--------|----------------|--------------------------|----------------------|
| **Approach** | Direct JOIN | CTE with Subquery | CTE with JOIN |
| **Returns Sales Amount** |  Yes |  No |  Yes |
| **Memory Granted** | 5,648 KB | **3,016 KB** | 5,648 KB |
| **Logical Reads (No Index)** | ~1,250 | ~1,250 | ~1,250 |
| **Logical Reads (With Index)** | 288 | **288** | 288 |
| **Execution Time** | Similar | **Similar** | Similar |
| **Memory Efficiency** | Standard | **Best** | Standard |

---

### Execution Plan Analysis

**Similarities:**
- All three queries use comparable operators when the same indexes are available
- SQL Server optimizer generates similar execution strategies
- Parallelism utilized automatically for large table scans
- Syntax differences have minimal impact

**Key Difference:**
- **Memory allocation** is the primary differentiator
- Query 2 requires ~50% less memory due to simpler result set (no aggregated sales amount)

---

### Index Impact Analysis

#### Nonclustered Index Impact

| Query | Logical Reads (Before) | Logical Reads (After) | Reduction |
|-------|------------------------|----------------------|-----------|
| Query 1 | 1,252 | 288 | 77% |
| Query 2 | 1,252 | 288 | 77% |
| Query 3 | 1,252 | 288 | 77% |

**Observation:** Despite dramatic reduction in logical reads, CPU time slightly increased, demonstrating that I/O optimization doesn't always correlate with CPU efficiency.

#### Columnstore Index Impact

- **Logical reads:** Reduced to nearly 0
- **Execution time:** Dramatically improved for repeated queries
- **Best use case:** Read-intensive analytical workloads (OLAP)
- **Not recommended for:** Transaction-heavy systems (OLTP)

---

## Conclusions

### Winner: Query 2 (Resource Efficiency)

**Reasons:**
- **50% less memory consumption** (3,016 KB vs 5,648 KB)
- **Lowest logical reads** in all scenarios
- **Equivalent execution time** to other queries
- Most resource-efficient solution

**Trade-off:**
- Does not return total sales amount
- Suitable when only customer identification is needed

---

### When to Use Each Query

#### Use Query 1 (JOIN-Based)
- When total sales amount is required
- Traditional SQL approach preferred
- Standard reporting scenarios

#### Use Query 2 (CTE + Subquery)
- **Resource-constrained environments**
- High-traffic systems with limited memory
- When only customer identification needed
- Maximum resource efficiency required

#### Use Query 3 (CTE + JOIN)
- When total sales amount is required
- Preference for CTE-based code structure
- Similar performance to Query 1

---

### Index Recommendations

#### For OLTP (Transaction Processing)
**Recommended:** Nonclustered Index
```sql
CREATE NONCLUSTERED INDEX idx_FactInternetSales_CustomerKey_SalesAmount
ON dbo.FactInternetSales (CustomerKey)
INCLUDE (SalesAmount);
```
- Balances read and write performance
- Significant reduction in logical reads
- Maintains acceptable write speeds

#### For OLAP (Analytical Processing)
**Recommended:** Nonclustered Columnstore Index
```sql
CREATE NONCLUSTERED COLUMNSTORE INDEX nccidx_FactInternetSales_CustomerKey_SalesAmount
ON dbo.FactInternetSales (CustomerKey, SalesAmount);
```
- Optimal for aggregation queries
- Best for read-heavy data warehouse scenarios
- Dramatic performance improvements
- **Caution:** Reduced write performance

---

## Performance Metrics Collected

Throughout all tests, the following metrics were captured:

- **Execution Time** – Total elapsed time (milliseconds)
- **CPU Time** – Processor time consumed (milliseconds)
- **Logical Reads** – Pages read from buffer cache
- **Physical Reads** – Pages read from disk
- **Read-Ahead Reads** – Pages read asynchronously
- **Memory Granted** – Memory allocated for query execution (KB)
- **Scan Count** – Number of index/table scans performed

All metrics were analyzed using [statisticsparser.com](https://statisticsparser.com/) and recorded in the Excel file.

---

## Files Included

### SQL Files
- **SQL_2_Assignment_2_CL.sql** – Complete implementation with:
  - All three query variations
  - Test harness for 100-run testing
  - Index creation scripts
  - Statistical analysis queries

### Execution Plans (15 files total)
- **Original table plans** (3 files) – Initial tests on FactInternetSales
- **Big table plans** (3 files) – Tests on RawFactInternetSalesBig (100x data)
- **With nonclustered index** (6 files) – Both original and big table
- **With columnstore index** (3 files) – Optimal indexing strategy

### Data Files
- **SQL_2_Assignment_2_CL.xlsx** – Complete performance metrics:
  - Raw measurement data
  - Statistical analysis
  - Comparison charts
  - I/O metrics visualization

### Documentation
- **SQL_2_Assignment_2_PDF.pdf** – Full Swedish-language analysis report with:
  - Detailed methodology
  - Visual performance comparisons
  - Comprehensive conclusions

---

## How to Use This Project

### Prerequisites
- SQL Server 2016 or later
- AdventureWorksDW2019 database
- SQL Server Management Studio (SSMS) for viewing .sqlplan files
- Excel for viewing performance metrics

### Running the Analysis

#### Step 1: Prepare Database
```sql
USE AdventureWorksDW2019;
GO
```

#### Step 2: Enable Statistics
```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
```

#### Step 3: Run Individual Queries
Execute queries from **Section 2** of the SQL file to test each approach once.

#### Step 4: Create Large Test Table
Execute **Section 3** to create `RawFactInternetSalesBig` (100x original data).

#### Step 5: Run 100-Iteration Tests
Execute **Section 4** to run each query 100 times and collect statistical data.

#### Step 6: Test Index Strategies
Execute **Section 5** to create and test nonclustered and columnstore indexes.

#### Step 7: Analyze Results
- Open .sqlplan files in SSMS
- Review Excel file for metrics
- Compare execution plans side-by-side

### Viewing Execution Plans
1. Open SQL Server Management Studio
2. File → Open → File
3. Select any .sqlplan file
4. Analyze operators, costs, and execution flow

---

## Technologies Used

- **Database System:** Microsoft SQL Server
- **Sample Database:** AdventureWorksDW2019
- **Analysis Tools:** 
  - SQL Server Management Studio (SSMS)
  - [Statistics Parser](https://statisticsparser.com/)
  - Microsoft Excel
- **Demo Platform:** [Lovable](https://sql2assignment2.lovable.app)

---

## Project Learnings

This assignment demonstrates:

1. **Query Optimization Techniques**
   - Different approaches to achieve the same result
   - Impact of query structure on resource consumption

2. **Performance Analysis Methodology**
   - Scientific approach to benchmarking
   - Statistical outlier removal
   - Reliable average calculations

3. **Index Strategy Selection**
   - Nonclustered indexes for balanced workloads
   - Columnstore indexes for analytical queries
   - Trade-offs between read and write performance

4. **SQL Server Internals**
   - Memory grant allocation
   - Execution plan generation
   - Parallel query execution
   - Buffer cache behavior

5. **Real-World Decision Making**
   - Balancing performance vs business requirements
   - Resource constraint considerations
   - Workload-appropriate optimization

---

## Key Takeaways

### The Most Efficient Query Depends on Context

**For Resource Efficiency:**
- Choose **Query 2** (CTE + Subquery without sales amount)
- 50% less memory, lowest I/O, same speed

**For Complete Business Intelligence:**
- Choose **Query 1** (JOIN) or **Query 3** (CTE + JOIN)
- Provides total sales amount at the cost of higher memory usage

**For Analytical Workloads:**
- Implement **columnstore indexes**
- Best for read-heavy data warehouse scenarios

**For Transactional Systems:**
- Implement **nonclustered indexes**
- Balances read optimization with write performance

### Performance Optimization is Multi-Dimensional

This project proves that:
- Fewer logical reads ≠ lower CPU usage
- Similar execution times can mask different resource consumption
- Memory efficiency is often overlooked but critical
- The "best" query depends on system constraints and requirements

---

## Future Enhancements

Potential extensions to this analysis:

- Test with even larger datasets (1000x, 10000x)
- Analyze performance under concurrent load
- Compare different isolation levels
- Test with filtered indexes for specific customer segments
- Implement clustered columnstore indexes
- Analyze query performance across different SQL Server versions
- Test impact of statistics updates on query plans
- Measure performance with different MAXDOP settings

---

## Demo & Visualization

**Interactive Dashboard:** [https://sql2assignment2.lovable.app](https://sql2assignment2.lovable.app)

The demo provides:
- Visual comparison of all three queries
- Performance metrics visualization
- Execution plan summaries
- Index impact analysis
- Interactive charts and graphs

---

## License

Educational project for DE25 course.

---

## Author

**Christofer Lindholm**  
DE25 Course  
Date: 2025-11-16

---

## Contact & Repository

**GitHub Repository:** [Your Repository URL Here]

For questions about this analysis or methodology, please refer to the full Swedish report in the `docs/` folder or explore the interactive demo at the link above.

---

## Acknowledgments

- **AdventureWorksDW2019** database by Microsoft
- **Statistics Parser** tool for metrics analysis
- **Lovable** platform for interactive demo hosting

---

*This project demonstrates that SQL query optimization requires understanding not just execution speed, but the complete resource consumption profile including memory, I/O, and CPU usage. The most efficient solution balances all these factors against real-world business requirements.*
