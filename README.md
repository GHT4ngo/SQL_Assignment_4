# SQL_2_Assignment – Query Performance Analysis

**Author:** Christofer Lindholm  
**Course:** DE25  
**Date:** 2025-11-16

---

## Overview

This project analyzes and compares the performance of three different SQL queries designed to identify the top-spending customer in the AdventureWorksDW2019 database. The analysis includes execution plans, resource utilization metrics, and indexing optimization strategies.

**Database:** AdventureWorksDW2019  
**Tables Used:** 
- `DimCustomer`
- `FactInternetSales`

**Live Demo:** [View Interactive Dashboard](https://sql2assignment2.lovable.app)

---

## Assignment Objective

Retrieve information about the customer who has spent the most money, including:
- Customer's first name
- Customer's last name
- Total amount spent (optional)

Compare multiple query approaches to determine the most efficient solution based on:
- Execution plans
- I/O statistics
- Memory usage
- CPU consumption

---

## Project Structure
```
SQL_2_Assignment_2/
├── sql/                      # SQL query files
├── execution-plans/          # Execution plan files organized by test scenario
│   ├── original/            # Plans from initial FactInternetSales table
│   ├── big-table/           # Plans from RawFactInternetSalesBig (100x data)
│   ├── with-index/          # Plans with nonclustered index
│   └── with-columnstore/    # Plans with columnstore index
├── data/                     # Performance metrics (Excel)
├── docs/                     # Full analysis report (PDF)
└── demo/                     # Link to interactive demo
```

---

## Queries Implemented

### Query 1
Uses aggregation with `GROUP BY` and returns both customer name and total sales amount.

**Features:**
- Returns complete business information
- Higher memory consumption (5648 KB)
- Includes `SUM(SalesAmount)`

### Query 2
Optimized query focusing on customer identification without aggregating sales amount.

**Features:**
- Lowest memory usage (3016 KB)
- Lowest logical reads
- Does not return total sales amount
- **Most resource-efficient option**

### Query 3
Alternative aggregation approach with different sorting strategy.

**Features:**
- Returns complete business information
- Similar performance to Query 1
- Memory consumption: 5648 KB

---

## Testing Methodology

### Phase 1: Initial Testing
- Executed queries against original `FactInternetSales` table
- Analyzed execution plans and memory grants
- Measured initial performance metrics

### Phase 2: Large-Scale Testing
- Created `RawFactInternetSalesBig` (100x original data size)
- Executed each query 100 times
- Excluded top 5 and bottom 5 outliers
- Calculated average CPU time and execution time

### Phase 3: Index Optimization
Tested three indexing strategies:

1. **No Index** (baseline)
2. **Nonclustered Index**
```sql
   CREATE NONCLUSTERED INDEX IX_CustomerKey_SalesAmount
   ON FactInternetSales (CustomerKey)
   INCLUDE (SalesAmount);
```

3. **Columnstore Index**
```sql
   CREATE NONCLUSTERED COLUMNSTORE INDEX IX_Columnstore
   ON FactInternetSales (CustomerKey, SalesAmount);
```

---

## Key Findings

### Performance Comparison

| Metric | Query 1 | Query 2 | Query 3 |
|--------|---------|---------|---------|
| Memory Granted | 5648 KB | 3016 KB | 5648 KB |
| Logical Reads (No Index) | ~1250 | ~1250 | ~1250 |
| Logical Reads (With Index) | 288 | 288 | 288 |
| Returns Sales Amount | Yes | No | Yes |
| Execution Time | Similar | Similar | Similar |

### Index Impact

**Nonclustered Index:**
- Reduced logical reads significantly (1252 → 288 for Query 2)
- Slightly increased CPU time
- Demonstrates that fewer logical reads ≠ lower CPU usage

**Columnstore Index:**
- Best performance for large-scale aggregations
- Logical reads reduced to nearly zero
- Dramatic improvement in execution time over 100 runs
- **Trade-off:** Reduced write performance
- **Recommended for:** Read-heavy analytical workloads

### Execution Plan Analysis

- All three queries generate similar execution plans when using the same indexes
- SQL Server optimizer produces comparable execution strategies
- Syntax differences have minimal impact on execution time
- Parallelism utilized automatically for large table scans
- Memory allocation is the primary differentiator

---

## Conclusions

### Winner: Query 2

**Reasons:**
- **50% less memory consumption** (3016 KB vs 5648 KB)
- **Lowest logical reads** across all scenarios
- **Equivalent execution time** to other queries
- Most resource-efficient solution

**Trade-off:**
- Does not return total sales amount
- Suitable when only customer identification is needed

### When to Use Each Query

**Query 1 / Query 3:**
- When total sales amount is required
- When complete business intelligence is needed
- Acceptable memory overhead

**Query 2:**
- High-traffic environments
- Limited memory resources
- Customer identification only
- Maximum resource efficiency required

### Index Recommendation

**For OLTP (Transaction Processing):**
- Use nonclustered index on CustomerKey with SalesAmount included
- Balances read and write performance

**For OLAP (Analytical Processing):**
- Use columnstore index
- Optimal for aggregation queries
- Best for read-heavy data warehouse scenarios

---

## Files Included

### SQL Files
- `SQL_2_Assignment_2_CL.sql` - All three query implementations plus test setup

### Execution Plans (15 files)
- Original table plans (3 files)
- Big table plans (3 files)
- With nonclustered index (6 files)
- With columnstore index (3 files)

### Data Files
- `SQL_2_Assignment_2_CL.xlsx` - Performance metrics and measurements

### Documentation
- `SQL_2_Assignment_2_PDF.pdf` - Complete Swedish-language analysis report

---

## How to Use

### Prerequisites
- SQL Server 2016 or later
- AdventureWorksDW2019 database
- SQL Server Management Studio (for viewing .sqlplan files)

### Running the Analysis

1. **Restore AdventureWorksDW2019 database**

2. **Execute the SQL file:**
```sql
   USE AdventureWorksDW2019;
   GO
   
   -- Run queries from SQL_2_Assignment_2_CL.sql
```

3. **View execution plans:**
   - Open .sqlplan files in SSMS
   - Analyze execution costs and operators

4. **Review metrics:**
   - Open Excel file for detailed statistics
   - Compare memory, CPU, and I/O metrics

5. **Explore interactive demo:**
   - Visit: https://sql2assignment2.lovable.app

---

## Performance Metrics Collected

- **Execution Time** (elapsed time in milliseconds)
- **CPU Time** (processor time in milliseconds)
- **Logical Reads** (pages read from buffer cache)
- **Physical Reads** (pages read from disk)
- **Memory Granted** (KB allocated for query execution)
- **Scan Count** (number of seeks/scans performed)

---

## Technologies Used

- **Database:** SQL Server / AdventureWorksDW2019
- **Tools:** SQL Server Management Studio
- **Analysis:** Excel for metrics visualization
- **Demo Platform:** Lovable (https://sql2assignment2.lovable.app)

---

## Project Learnings

This assignment demonstrates:

- Performance analysis of equivalent queries
- Impact of indexing strategies on query performance
- Trade-offs between memory, I/O, and CPU usage
- Importance of execution plan analysis
- Practical application of columnstore indexes
- Scientific methodology for performance testing
- SQL Server query optimization techniques

---

## Future Improvements

Potential extensions to this analysis:

- Test with even larger datasets (1000x, 10000x)
- Analyze impact of different isolation levels
- Compare performance with clustered columnstore indexes
- Test query performance under concurrent load
- Analyze impact of database compatibility levels
- Implement filtered indexes for specific customer segments

---

## Author Notes

This project showcases a methodical approach to query performance optimization. The key takeaway is that the most efficient query depends on specific requirements:

- **Resource-constrained environments:** Choose Query 2
- **Complete business intelligence:** Choose Query 1 or 3
- **Analytical workloads:** Implement columnstore indexes
- **Transactional systems:** Use nonclustered indexes

Real-world optimization requires balancing multiple factors: execution speed, resource consumption, and business requirements.

---

## License

Educational project for DE25 course.

---

## Contact

**Christofer Lindholm**  
DE25 Course  
[GitHub Repository](https://github.com/yourusername/SQL_2_Assignment_2)
```

---

## Additional Tips for GitHub

1. **Create a .gitignore file:**
```
*.tmp
*.bak
~$*.xlsx
.DS_Store
Thumbs.db# SQL_Assignment_4
SQL Assignment – Query Performance Analysis
