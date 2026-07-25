-- SQL_2_Assignment_2_Christofer_Lindholm

/*==============================================================

INDEX

1.  Förberedelser: Start av statistikmätning

2.  Utförande: 3 test Queries

    2.1 Query baserad på JOIN
    2.2 Query baserad på en SubQuery (utan spenderat belopp)
    2.3 Query baserad på en SubQuery och JOIN (med Spenderat belopp)

3.  Skapa RawFactInternetSalesBig

    3.1 Skapa tabell
    3.2 Skapa Index

4.  Köra testqueries 100 gånger för tidsmätning

    4.1 Köra 2.1 hundra gånger
    4.2 Köra 2.2 hundra gånger
    4.3 Köra 2.3 hundra gånger

5.  Indexering och Optimering

    5.1 Skapa och prova nonclustered index
    5.2 Skapa och prova columnstore index


==============================================================*/


----------------------------------------------------------------
-- 1.  Förberedelser: Start av statistikmätning
----------------------------------------------------------------

-- Val av databas
USE AdventureWorksDW2019 ;
GO

-- Visar sidläsningar samt CPU- och exekveringstid i Messages.
SET STATISTICS IO ON ;
SET STATISTICS TIME ON ;


----------------------------------------------------------------
-- 2.  Utförande: 3 test Queries
----------------------------------------------------------------

-- 2.1 Query 1 with JOIN

-- Tömmer cachen och execution plans så att de inte påverkar mätningen
-- OBS: Följande kommandon påverkar hela SQL Server-instansen.
-- Kör dem endast i en egen testmiljö, aldrig på en delad produktionsserver.
DBCC DROPCLEANBUFFERS ;
DBCC FREEPROCCACHE ;

-- Visar för- och efternamn samt spenderat belopp på den kund som spenderat mest
SELECT TOP 1
    c.FirstName
    ,c.LastName
    ,SUM(f.SalesAmount)     AS TotalSales
FROM dbo.DimCustomer        AS c
JOIN dbo.FactInternetSales  AS f
    ON f.CustomerKey = c.CustomerKey
GROUP BY
    c.CustomerKey
    ,c.FirstName
    ,c.LastName
ORDER BY
    TotalSales DESC
    ,c.CustomerKey

-- Mätvärden:

    -- Använde https://statisticsparser.com/ och skrev in resultatet i SQL_2_Assignment_2_CL.xlsx

    -- MemoryGrant = "5648" (kB)


-- 2.2 Query 2 med en CTE och SubQuery

-- Tömmer cachen och execution plans så att de inte påverkar mätningen
DBCC DROPCLEANBUFFERS ;
DBCC FREEPROCCACHE ;

-- Visar för- och efternamn på den som spenderat mest
WITH x AS(
SELECT
	CustomerKey
	,SUM(SalesAmount)   AS TotalSales
FROM dbo.FactInternetSales
GROUP BY CustomerKey
)

SELECT TOP 1
	c.FirstName
    ,c.LastName
FROM dbo.DimCustomer    AS c
WHERE CustomerKey IN (SELECT TOP 1
                        CustomerKey
                        FROM x
                        ORDER BY TotalSales DESC, CustomerKey
                      );

-- Mätvärden:

    -- Använde https://statisticsparser.com/ och skrev in resultatet i SQL_2_Assignment_2_CL.xlsx

    -- GrantedMemory = "3016" (kB)


-- 2.3 Query 3 med en CTE och SubQuery samt JOIN för att visa totalt spenderat belopp

-- Tömmer cachen och execution plans så att de inte påverkar mätningen
DBCC DROPCLEANBUFFERS ;
DBCC FREEPROCCACHE ;

-- Visar för- och efternamn samt spenderat belopp på den kund som spenderat mest
WITH x AS (
    SELECT
        CustomerKey
        ,SUM(SalesAmount)           AS TotalSales
    FROM dbo.FactInternetSales
    GROUP BY CustomerKey
)
SELECT TOP 1
    c.FirstName
    ,c.LastName
    ,x.TotalSales
FROM dbo.DimCustomer                AS c
JOIN x ON c.CustomerKey = x.CustomerKey
ORDER BY x.TotalSales DESC, c.CustomerKey;

-- Märtvärden:

    -- Använde https://statisticsparser.com/ och skrev in resultatet i SQL_2_Assignment_2_CL.xlsx

    -- GrantedMemory = "5648" (kB)


----------------------------------------------------------------
-- 3.  Skapa RawFactInternetSalesBig
----------------------------------------------------------------

-- 3.1 Skapa tabell

-- Skapa tabellen endast om den inte redan finns. Tabellen innehåller
-- FactInternetSales duplicerad hundra gånger och kräver mycket diskutrymme.
IF OBJECT_ID('dbo.RawFactInternetSalesBig', 'U') IS NULL
BEGIN
    SELECT f.*
    INTO dbo.RawFactInternetSalesBig
    FROM dbo.FactInternetSales AS f
    CROSS JOIN (
        SELECT TOP (100) 1 AS n
        FROM dbo.FactInternetSales
    ) AS x;

    -- Tabellen saknar originaltabellens primärnyckel, så ett clustered index
    -- skapas för att ge den en liknande fysisk struktur.
    CREATE CLUSTERED INDEX idx_RawFactInternetSalesBig_SalesOrderNumber
    ON dbo.RawFactInternetSalesBig (SalesOrderNumber);
END
ELSE
BEGIN
    PRINT 'RawFactInternetSalesBig finns redan och skapades inte på nytt.';
END;


----------------------------------------------------------------
-- 4.  Köra testqueries 100 gånger för tidsmätning
----------------------------------------------------------------

-- Stänger av meddelanden från STATISTICS under de upprepade mätningarna.
SET STATISTICS IO OFF ;
SET STATISTICS TIME OFF ;

/*
    CPU-tiden nedan läses från den aktuella SQL-sessionen via
    sys.dm_exec_sessions. Den äldre variabeln @@CPU_BUSY mäter hela servern
    och kan därför påverkas av andra användare.

    DBCC-kommandona i avsnittet påverkar hela instansen. Kör avsnitt 4 endast
    i en egen testmiljö.
*/


-- 4.1 Köra 2.1 hundra gånger

-- Tömmer cachen och execution plans så att de inte påverkar mätningen
DBCC DROPCLEANBUFFERS ;
DBCC FREEPROCCACHE ;

-- Stänger av medelanden
SET NOCOUNT ON;

-- Skapa en temptabell att för resultatet
CREATE TABLE #ExecutionTimes (
    RunNumber       INT
    ,CPUTime        INT
    ,ElapsedTime    INT
);

-- Skapa variabler
DECLARE @Cnt            INT = 1;
DECLARE @StartTime      DATETIME2;
DECLARE @CPUStart       INT;
DECLARE @CPUEnd         INT;
DECLARE @ElapsedTime    INT;

-- Kör en testquery ett hundra gånger
WHILE @Cnt <= 100
BEGIN

    -- Spara starttid för cpu- och totaltidsmärning
    SELECT @CPUStart = cpu_time
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;
    SET @StartTime      = SYSDATETIME();

    -- Query 1 mot RawFactInternetSalesBig istället för FactInternetSales
    SELECT TOP 1
        c.FirstName
        ,c.LastName
        ,SUM(f.SalesAmount)             AS TotalSales
    FROM dbo.DimCustomer                AS c
    JOIN dbo.RawFactInternetSalesBig    AS f
        ON f.CustomerKey = c.CustomerKey
    GROUP BY
        c.CustomerKey
        ,c.FirstName
        ,c.LastName
    ORDER BY
        TotalSales DESC

    -- RECOMPILE skapar en ny execution plan för varje körning.
    OPTION(RECOMPILE) ;

    -- Stoppa tidsmätningen och spara värden
    SELECT @CPUEnd = cpu_time
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;
    SET @ElapsedTime    = DATEDIFF(MILLISECOND, @StartTime, SYSDATETIME());

    -- Sätt in värden från tidsmätningen i temptabellen
    INSERT INTO #ExecutionTimes (RunNumber, CPUTime, ElapsedTime)
    VALUES (@Cnt, @CPUEnd - @CPUStart, @ElapsedTime);

    -- Uppdaterar räknaren av antal körda gånger
    SET @Cnt = @Cnt + 1;
END

-- Visar tabellen med mätvärden
SELECT
    RunNumber,
    CPUTime AS CPUTime_ms,
    ElapsedTime AS ElapsedTime_ms
FROM #ExecutionTimes
ORDER BY RunNumber;

-- Kalkulerar statestik på uppmätta värden, de 5 högsta och lägsta resultaten används
-- inte så att avvikelser inte förstör mätningen
WITH RankedResults AS (
    SELECT
        CPUTime
        ,ElapsedTime
        ,ROW_NUMBER() OVER (ORDER BY ElapsedTime) AS RowNum
    FROM #ExecutionTimes
),
FilteredResults AS (
    SELECT
        CPUTime
        ,ElapsedTime
    FROM RankedResults
    WHERE RowNum > 5 AND RowNum <= 95
)
SELECT
    COUNT(*)            AS SampleSize,
    AVG(CPUTime)        AS AvgCPUTime_ms,
    AVG(ElapsedTime)    AS AvgElapsedTime_ms,
    MIN(CPUTime)        AS MinCPUTime_ms,
    MAX(CPUTime)        AS MaxCPUTime_ms,
    MIN(ElapsedTime)    AS MinElapsedTime_ms,
    MAX(ElapsedTime)    AS MaxElapsedTime_ms
FROM FilteredResults;

-- Ta bort temptabellen
DROP TABLE #ExecutionTimes ;
GO


-- 4.2 Köra 2.2 hundra gånger

-- Tömmer cachen och execution plans så att de inte påverkar mätningen
DBCC DROPCLEANBUFFERS ;
DBCC FREEPROCCACHE ;

-- Stänger av medelanden
SET NOCOUNT ON;

-- Skapa en temptabell att för resultatet
CREATE TABLE #ExecutionTimes (
    RunNumber       INT
    ,CPUTime        INT
    ,ElapsedTime    INT
);

-- Skapa variabler
DECLARE @Cnt            INT = 1;
DECLARE @StartTime      DATETIME2;
DECLARE @CPUStart       INT;
DECLARE @CPUEnd         INT;
DECLARE @ElapsedTime    INT;

-- Kör en testquery ett hundra gånger
WHILE @Cnt <= 100
BEGIN

    -- Spara starttid för cpu- och totaltidsmärning
    SELECT @CPUStart = cpu_time
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;
    SET @StartTime      = SYSDATETIME();

    -- Query 2 mot RawFactInternetSalesBig istället för FactInternetSales
    WITH x AS(
    SELECT
    	CustomerKey
    	,SUM(SalesAmount)   AS TotalSales
    FROM dbo.RawFactInternetSalesBig
    GROUP BY CustomerKey
    )

    SELECT
    	c.FirstName
        ,c.LastName
    FROM dbo.DimCustomer    AS c
    WHERE CustomerKey IN (SELECT TOP 1
                            CustomerKey
                            FROM x
                            ORDER BY TotalSales DESC, CustomerKey
                          )

    -- RECOMPILE skapar en ny execution plan för varje körning.
    OPTION(RECOMPILE);

    -- Stoppa tidsmätningen och spara värden
    SELECT @CPUEnd = cpu_time
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;
    SET @ElapsedTime    = DATEDIFF(MILLISECOND, @StartTime, SYSDATETIME());

    -- Sätt in värden från tidsmätningen i temptabellen
    INSERT INTO #ExecutionTimes (RunNumber, CPUTime, ElapsedTime)
    VALUES (@Cnt, @CPUEnd - @CPUStart, @ElapsedTime);

    -- Uppdaterar räknaren av antal körda gånger
    SET @Cnt = @Cnt + 1;
END

-- Visar tabellen med mätvärden
SELECT
    RunNumber,
    CPUTime AS CPUTime_ms,
    ElapsedTime AS ElapsedTime_ms
FROM #ExecutionTimes
ORDER BY RunNumber;

-- Kalkulerar statestik på uppmätta värden, de 5 högsta och lägsta resultaten används
-- inte så att avvikelser inte förstör mätningen
WITH RankedResults AS (
    SELECT
        CPUTime
        ,ElapsedTime
        ,ROW_NUMBER() OVER (ORDER BY ElapsedTime) AS RowNum
    FROM #ExecutionTimes
),
FilteredResults AS (
    SELECT
        CPUTime
        ,ElapsedTime
    FROM RankedResults
    WHERE RowNum > 5 AND RowNum <= 95
)
SELECT
    COUNT(*)            AS SampleSize,
    AVG(CPUTime)        AS AvgCPUTime_ms,
    AVG(ElapsedTime)    AS AvgElapsedTime_ms,
    MIN(CPUTime)        AS MinCPUTime_ms,
    MAX(CPUTime)        AS MaxCPUTime_ms,
    MIN(ElapsedTime)    AS MinElapsedTime_ms,
    MAX(ElapsedTime)    AS MaxElapsedTime_ms
FROM FilteredResults;

-- Ta bort temptabellen
DROP TABLE #ExecutionTimes ;
GO

-- 4.3 Köra 2.3 hundra gånger

-- Tömmer cachen och execution plans så att de inte påverkar mätningen
DBCC DROPCLEANBUFFERS ;
DBCC FREEPROCCACHE ;

-- Stänger av medelanden
SET NOCOUNT ON;

-- Skapa en temptabell att för resultatet
CREATE TABLE #ExecutionTimes (
    RunNumber       INT
    ,CPUTime        INT
    ,ElapsedTime    INT
);

-- Skapa variabler
DECLARE @Cnt            INT = 1;
DECLARE @StartTime      DATETIME2;
DECLARE @CPUStart       INT;
DECLARE @CPUEnd         INT;
DECLARE @ElapsedTime    INT;

-- Kör en testquery ett hundra gånger
WHILE @Cnt <= 100
BEGIN

    -- Spara starttid för cpu- och totaltidsmärning
    SELECT @CPUStart = cpu_time
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;
    SET @StartTime      = SYSDATETIME();

    -- Query 3 mot RawFactInternetSalesBig istället för FactInternetSales
    WITH x AS (
        SELECT
            CustomerKey
            ,SUM(SalesAmount)           AS TotalSales
        FROM dbo.RawFactInternetSalesBig
        GROUP BY CustomerKey
    )
    SELECT TOP 1
        c.FirstName
        ,c.LastName
        ,x.TotalSales
    FROM dbo.DimCustomer                AS c
    JOIN x ON c.CustomerKey = x.CustomerKey
    ORDER BY x.TotalSales DESC, c.CustomerKey

    -- RECOMPILE skapar en ny execution plan för varje körning.
    OPTION(RECOMPILE);

    -- Stoppa tidsmätningen och spara värden
    SELECT @CPUEnd = cpu_time
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;
    SET @ElapsedTime    = DATEDIFF(MILLISECOND, @StartTime, SYSDATETIME());

    -- Sätt in värden från tidsmätningen i temptabellen
    INSERT INTO #ExecutionTimes (RunNumber, CPUTime, ElapsedTime)
    VALUES (@Cnt, @CPUEnd - @CPUStart, @ElapsedTime);

    -- Uppdaterar räknaren av antal körda gånger
    SET @Cnt = @Cnt + 1;
END

-- Visar tabellen med mätvärden
SELECT
    RunNumber,
    CPUTime AS CPUTime_ms,
    ElapsedTime AS ElapsedTime_ms
FROM #ExecutionTimes
ORDER BY RunNumber;

-- Kalkulerar statestik på uppmätta värden, de 5 högsta och lägsta resultaten används
-- inte så att avvikelser inte förstör mätningen
WITH RankedResults AS (
    SELECT
        CPUTime
        ,ElapsedTime
        ,ROW_NUMBER() OVER (ORDER BY ElapsedTime) AS RowNum
    FROM #ExecutionTimes
),
FilteredResults AS (
    SELECT
        CPUTime
        ,ElapsedTime
    FROM RankedResults
    WHERE RowNum > 5 AND RowNum <= 95
)
SELECT
    COUNT(*)            AS SampleSize,
    AVG(CPUTime)        AS AvgCPUTime_ms,
    AVG(ElapsedTime)    AS AvgElapsedTime_ms,
    MIN(CPUTime)        AS MinCPUTime_ms,
    MAX(CPUTime)        AS MaxCPUTime_ms,
    MIN(ElapsedTime)    AS MinElapsedTime_ms,
    MAX(ElapsedTime)    AS MaxElapsedTime_ms
FROM FilteredResults;

-- Ta bort temptabellen
DROP TABLE #ExecutionTimes ;
GO


----------------------------------------------------------------
-- 5.  Indexering och Optimering
----------------------------------------------------------------

-- Välj ett test i taget: NONE, NONCLUSTERED eller COLUMNSTORE.
DECLARE @IndexTest VARCHAR(20) = 'NONE';

-- 5.1 Skapa och prova nonclustered index

IF @IndexTest = 'NONCLUSTERED'
BEGIN
    -- Skapar ett index på CustomerKey och inkluderar SalesAmount.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.FactInternetSales')
          AND [name] = 'idx_FactInternetSales_CustomerKey_SalesAmount'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX idx_FactInternetSales_CustomerKey_SalesAmount
        ON dbo.FactInternetSales (CustomerKey)
        INCLUDE (SalesAmount);
    END;

    -- Skapar motsvarande index på den stora testtabellen.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.RawFactInternetSalesBig')
          AND [name] = 'idx_RawFactInternetSalesBig_CustomerKey_SalesAmount'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX idx_RawFactInternetSalesBig_CustomerKey_SalesAmount
        ON dbo.RawFactInternetSalesBig (CustomerKey)
        INCLUDE (SalesAmount);
    END;
END;

-- Kör testfrågorna och spara mätvärden innan indexen tas bort.
-- DROP INDEX idx_FactInternetSales_CustomerKey_SalesAmount
-- ON dbo.FactInternetSales;
-- DROP INDEX idx_RawFactInternetSalesBig_CustomerKey_SalesAmount
-- ON dbo.RawFactInternetSalesBig;

-- 5.2 Skapa och prova nonclustered columnstore index

IF @IndexTest = 'COLUMNSTORE'
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.FactInternetSales')
          AND [name] = 'nccidx_FactInternetSales_CustomerKey_SalesAmount'
    )
    BEGIN
        CREATE NONCLUSTERED COLUMNSTORE INDEX nccidx_FactInternetSales_CustomerKey_SalesAmount
        ON dbo.FactInternetSales (CustomerKey, SalesAmount);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.RawFactInternetSalesBig')
          AND [name] = 'nccidx_RawFactInternetSalesBig_CustomerKey_SalesAmount'
    )
    BEGIN
        CREATE NONCLUSTERED COLUMNSTORE INDEX nccidx_RawFactInternetSalesBig_CustomerKey_SalesAmount
        ON dbo.RawFactInternetSalesBig (CustomerKey, SalesAmount);
    END;
END;

-- Kör testfrågorna och spara mätvärden innan indexen tas bort.
-- DROP INDEX nccidx_FactInternetSales_CustomerKey_SalesAmount
-- ON dbo.FactInternetSales;
-- DROP INDEX nccidx_RawFactInternetSalesBig_CustomerKey_SalesAmount
-- ON dbo.RawFactInternetSalesBig;

IF @IndexTest NOT IN ('NONE', 'NONCLUSTERED', 'COLUMNSTORE')
    PRINT 'Ogiltigt @IndexTest. Använd NONE, NONCLUSTERED eller COLUMNSTORE.';

-- Valfri städning efter att alla tester är klara:
-- DROP TABLE dbo.RawFactInternetSalesBig;
