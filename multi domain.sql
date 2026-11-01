USE BUSINESS_ANALYTICS_FINAL;
GO
CREATE VIEW Analytics.Q01_Monthly_Sales_Profit
AS
SELECT
    d.Year,
    d.Month,
    d.MonthName,
    SUM(f.SalesAmount) AS TotalSales,
    SUM(f.CostAmount) AS TotalCost,
    SUM(f.ProfitAmount) AS TotalProfit,
    CAST(
        100.0 * SUM(f.ProfitAmount)
        / NULLIF(SUM(f.SalesAmount), 0)
        AS DECIMAL(10,2)
    ) AS ProfitMarginPct
FROM dbo.FactSales f
JOIN dbo.DimDate d
    ON f.DateID = d.DateID
GROUP BY
    d.Year,
    d.Month,
    d.MonthName;
GO
/* =========================================================
   Q02 - Top 10 Products by Revenue
   ========================================================= */
CREATE OR ALTER VIEW Analytics.Q02_Top_Products
AS
SELECT TOP 10
    p.ProductID,
    p.ProductName,
    p.Category,
    p.SubCategory,
    SUM(f.Quantity) AS UnitsSold,
    SUM(f.SalesAmount) AS Revenue,
    SUM(f.ProfitAmount) AS Profit,
    CAST(
        100.0 * SUM(f.ProfitAmount)
        / NULLIF(SUM(f.SalesAmount),0)
        AS DECIMAL(10,2)
    ) AS ProfitMarginPct
FROM dbo.FactSales f
JOIN dbo.DimProduct p
    ON f.ProductID = p.ProductID
GROUP BY
    p.ProductID,
    p.ProductName,
    p.Category,
    p.SubCategory
ORDER BY Revenue DESC;
GO


/* =========================================================
   Q03 - Customer Segmentation / RFM
   ========================================================= */
CREATE OR ALTER VIEW Analytics.Q03_Customer_Segmentation
AS
WITH CustomerRFM AS
(
    SELECT
        c.CustomerID,
        c.CustomerName,
        c.Region,
        MAX(d.FullDate) AS LastPurchaseDate,
        DATEDIFF(
            DAY,
            MAX(d.FullDate),
            (SELECT MAX(FullDate) FROM dbo.DimDate)
        ) AS RecencyDays,
        COUNT(DISTINCT f.SaleID) AS Frequency,
        SUM(f.SalesAmount) AS MonetaryValue
    FROM dbo.DimCustomer c
    JOIN dbo.FactSales f
        ON c.CustomerID = f.CustomerID
    JOIN dbo.DimDate d
        ON f.DateID = d.DateID
    GROUP BY
        c.CustomerID,
        c.CustomerName,
        c.Region
),
Scored AS
(
    SELECT *,
        NTILE(4) OVER (ORDER BY RecencyDays DESC) AS RecencyScore,
        NTILE(4) OVER (ORDER BY Frequency) AS FrequencyScore,
        NTILE(4) OVER (ORDER BY MonetaryValue) AS MonetaryScore
    FROM CustomerRFM
)
SELECT
    CustomerID,
    CustomerName,
    Region,
    RecencyDays,
    Frequency,
    MonetaryValue,
    RecencyScore,
    FrequencyScore,
    MonetaryScore,
    CASE
        WHEN RecencyScore >= 3
         AND FrequencyScore >= 3
         AND MonetaryScore >= 3
            THEN 'VIP / High Value'
        WHEN MonetaryScore >= 3
         AND FrequencyScore >= 2
            THEN 'Loyal'
        WHEN RecencyScore <= 2
         AND FrequencyScore >= 2
            THEN 'At Risk'
        WHEN RecencyScore <= 2
         AND FrequencyScore <= 2
            THEN 'Lost / Inactive'
        ELSE 'Regular'
    END AS CustomerSegment
FROM Scored;
GO


/* =========================================================
   Q04 - Regional Performance
   ========================================================= */
CREATE OR ALTER VIEW Analytics.Q04_Regional_Performance
AS
SELECT
    c.Region,
    COUNT(DISTINCT f.CustomerID) AS ActiveCustomers,
    COUNT(DISTINCT f.SaleID) AS Orders,
    SUM(f.Quantity) AS UnitsSold,
    SUM(f.SalesAmount) AS Revenue,
    SUM(f.ProfitAmount) AS Profit,
    CAST(
        100.0 * SUM(f.ProfitAmount)
        / NULLIF(SUM(f.SalesAmount),0)
        AS DECIMAL(10,2)
    ) AS ProfitMarginPct
FROM dbo.FactSales f
JOIN dbo.DimCustomer c
    ON f.CustomerID = c.CustomerID
GROUP BY c.Region;
GO


/* =========================================================
   Q05 - Loan Approval Analysis
   ========================================================= */
CREATE OR ALTER VIEW Analytics.Q05_Loan_Approval
AS
SELECT
    LoanType,
    COUNT(*) AS TotalApplications,
    SUM(CASE WHEN LoanStatus = 'Approved' THEN 1 ELSE 0 END)
        AS ApprovedLoans,
    SUM(CASE WHEN LoanStatus = 'Rejected' THEN 1 ELSE 0 END)
        AS RejectedLoans,
    CAST(
        100.0 *
        SUM(CASE WHEN LoanStatus = 'Approved' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0)
        AS DECIMAL(10,2)
    ) AS ApprovalRatePct,
    SUM(
        CASE WHEN LoanStatus = 'Approved'
             THEN LoanAmount ELSE 0 END
    ) AS ApprovedLoanValue,
    AVG(
        CASE WHEN LoanStatus = 'Approved'
             THEN LoanAmount END
    ) AS AvgApprovedLoanAmount
FROM dbo.FactLoans
GROUP BY LoanType;
GO


/* =========================================================
   Q06 - Loan Default / Risk Analysis
   ========================================================= */
SELECT
    l.LoanType,
    CASE
        WHEN l.InterestRate < 10 THEN 'Low Rate'
        WHEN l.InterestRate < 16 THEN 'Medium Rate'
        ELSE 'High Rate'
    END AS InterestRateBand,
    COUNT(*) AS TotalLoans,
    SUM(CAST(l.DefaultFlag AS INT)) AS Defaults,
    CAST(100.0 * SUM(CAST(l.DefaultFlag AS INT)) / NULLIF(COUNT(*),0) AS DECIMAL(10,2)) AS DefaultRatePct,
    SUM(l.LoanAmount) AS TotalLoanAmount,
    AVG(l.LoanAmount) AS AvgLoanAmount
FROM dbo.FactLoans l
WHERE l.LoanStatus = 'Approved'
GROUP BY
    l.LoanType,
    CASE
        WHEN l.InterestRate < 10 THEN 'Low Rate'
        WHEN l.InterestRate < 16 THEN 'Medium Rate'
        ELSE 'High Rate'
    END
ORDER BY DefaultRatePct DESC;




/* =========================================================
   Q07 - Transaction Analysis
   ========================================================= */

SELECT
    d.Year,
    d.Month,
    d.MonthName,
    t.TransactionType,
    t.TransactionStatus,
    COUNT(*) AS TransactionCount,
    SUM(t.Amount) AS TransactionValue,
    AVG(t.Amount) AS AvgTransactionValue
FROM dbo.FactTransactions t
JOIN dbo.DimDate d
    ON t.DateID = d.DateID
GROUP BY
    d.Year,
    d.Month,
    d.MonthName,
    t.TransactionType,
    t.TransactionStatus;



/* =========================================================
   Q08 - Customer Financial Value
   ========================================================= */

WITH TransactionValue AS
(
    SELECT
        CustomerID,
        SUM(Amount) AS TotalTransactionValue,
        COUNT(*) AS TransactionCount
    FROM dbo.FactTransactions
    WHERE TransactionStatus = 'Completed'
    GROUP BY CustomerID
),
LoanValue AS
(
    SELECT
        CustomerID,
        SUM(
            CASE
                WHEN LoanStatus = 'Approved'
                THEN LoanAmount
                ELSE 0
            END
        ) AS ApprovedLoanValue,
        SUM(
            CASE
                WHEN LoanStatus = 'Approved'
                THEN 1
                ELSE 0
            END
        ) AS ApprovedLoanCount,
        SUM(CAST(DefaultFlag AS INT)) AS DefaultCount
    FROM dbo.FactLoans
    GROUP BY CustomerID
)
SELECT
    c.CustomerID,
    c.CustomerName,
    c.Region,
    c.IncomeBand,
    ISNULL(t.TotalTransactionValue,0) AS TotalTransactionValue,
    ISNULL(t.TransactionCount,0) AS TransactionCount,
    ISNULL(l.ApprovedLoanValue,0) AS ApprovedLoanValue,
    ISNULL(l.ApprovedLoanCount,0) AS ApprovedLoanCount,
    ISNULL(l.DefaultCount,0) AS DefaultCount,
    ISNULL(t.TotalTransactionValue,0)
        + ISNULL(l.ApprovedLoanValue,0) AS FinancialValue
FROM dbo.DimCustomer c
LEFT JOIN TransactionValue t
    ON c.CustomerID = t.CustomerID
LEFT JOIN LoanValue l
    ON c.CustomerID = l.CustomerID
WHERE t.CustomerID IS NOT NULL
   OR l.CustomerID IS NOT NULL;



/* =========================================================
   Q09 - Patient Visit Trend
   ========================================================= */

SELECT
    d.Year,
    d.Month,
    d.MonthName,
    COUNT(*) AS TotalVisits,
    SUM(
        CASE WHEN v.VisitStatus = 'Completed'
             THEN 1 ELSE 0 END
    ) AS CompletedVisits,
    SUM(
        CASE WHEN v.VisitStatus = 'Cancelled'
             THEN 1 ELSE 0 END
    ) AS CancelledVisits,
    SUM(
        CASE WHEN v.VisitStatus = 'No Show'
             THEN 1 ELSE 0 END
    ) AS NoShowVisits,
    SUM(v.TreatmentCost) AS TotalTreatmentCost
FROM dbo.FactHealthcareVisits v
JOIN dbo.DimDate d
    ON v.DateID = d.DateID
GROUP BY
    d.Year,
    d.Month,
    d.MonthName;
GO


/* =========================================================
   Q10 - Department Performance
   ========================================================= */
CREATE OR ALTER VIEW Analytics.Q10_Department_Performance
AS
SELECT
    dp.DepartmentID,
    dp.DepartmentName,
    dp.DepartmentType,
    COUNT(*) AS TotalVisits,
    SUM(
        CASE WHEN v.VisitStatus = 'Completed'
             THEN 1 ELSE 0 END
    ) AS CompletedVisits,
    SUM(v.TreatmentCost) AS TotalTreatmentCost,
    AVG(v.TreatmentCost) AS AvgTreatmentCost,
    CAST(
        100.0 *
        SUM(
            CASE WHEN v.VisitStatus = 'Completed'
                 THEN 1 ELSE 0 END
        )
        / NULLIF(COUNT(*),0)
        AS DECIMAL(10,2)
    ) AS CompletionRatePct
FROM dbo.FactHealthcareVisits v
JOIN dbo.DimDepartment dp
    ON v.DepartmentID = dp.DepartmentID
GROUP BY
    dp.DepartmentID,
    dp.DepartmentName,
    dp.DepartmentType;
GO

USE BUSINESS_ANALYTICS;
GO


USE BUSINESS_ANALYTICS;
GO

SELECT
    fk.name AS ForeignKeyName,
    OBJECT_NAME(fk.parent_object_id) AS ForeignKeyTable,
    COL_NAME(
        fkc.parent_object_id,
        fkc.parent_column_id
    ) AS ForeignKeyColumn,
    OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
    COL_NAME(
        fkc.referenced_object_id,
        fkc.referenced_column_id
    ) AS ReferencedColumn
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
    ON fk.object_id = fkc.constraint_object_id
ORDER BY ForeignKeyTable, ReferencedTable;

/* =========================================================
   Q11 - Visit Status Analysis
   ========================================================= */

SELECT
    dp.DepartmentName,
    v.VisitType,
    v.VisitStatus,
    COUNT(*) AS VisitCount,
    SUM(v.TreatmentCost) AS TreatmentCost
FROM dbo.FactHealthcareVisits v
JOIN dbo.DimDepartment dp
    ON v.DepartmentID = dp.DepartmentID
GROUP BY
    dp.DepartmentName,
    v.VisitType,
    v.VisitStatus;



/* =========================================================
   Q12 - Patient Segmentation
   ========================================================= */
WITH PatientVisits AS
(
    SELECT
        c.CustomerID,
        c.CustomerName,
        c.Gender,
        c.Region,
        COUNT(v.VisitID) AS VisitFrequency,
        SUM(v.TreatmentCost) AS TotalTreatmentCost,
        AVG(
            CAST(v.PatientAge AS DECIMAL(10,2))
        ) AS AvgPatientAge
    FROM dbo.DimCustomer c
    JOIN dbo.FactHealthcareVisits v
        ON c.CustomerID = v.CustomerID
    GROUP BY
        c.CustomerID,
        c.CustomerName,
        c.Gender,
        c.Region
)
SELECT
    CustomerID,
    CustomerName,
    Gender,
    Region,
    AvgPatientAge,
    VisitFrequency,
    TotalTreatmentCost,
    CASE
        WHEN VisitFrequency >= 5
            THEN 'Frequent Patient'
        WHEN VisitFrequency >= 3
            THEN 'Regular Patient'
        WHEN VisitFrequency = 2
            THEN 'Occasional Patient'
        ELSE 'Single Visit'
    END AS PatientSegment
FROM PatientVisits;



/* =========================================================
   Q13 - Campaign Performance
   ========================================================= */

SELECT
    c.CampaignID,
    c.CampaignName,
    c.CampaignType,
    c.Objective,
    SUM(m.Impressions) AS Impressions,
    SUM(m.Clicks) AS Clicks,
    SUM(m.Conversions) AS Conversions,
    SUM(m.Spend) AS Spend,
    SUM(m.Revenue) AS Revenue,
    CAST(
        100.0 * SUM(m.Clicks)
        / NULLIF(SUM(m.Impressions),0)
        AS DECIMAL(10,2)
    ) AS CTRPct,
    CAST(
        100.0 * SUM(m.Conversions)
        / NULLIF(SUM(m.Clicks),0)
        AS DECIMAL(10,2)
    ) AS ConversionRatePct,
    CAST(
        SUM(m.Revenue)
        / NULLIF(SUM(m.Spend),0)
        AS DECIMAL(10,2)
    ) AS ROAS,
    CAST(
        (SUM(m.Revenue) - SUM(m.Spend))
        / NULLIF(SUM(m.Spend),0) * 100.0
        AS DECIMAL(10,2)
    ) AS ROIPct
FROM dbo.FactMarketing m
JOIN dbo.DimCampaign c
    ON m.CampaignID = c.CampaignID
GROUP BY
    c.CampaignID,
    c.CampaignName,
    c.CampaignType,
    c.Objective;


/* =========================================================
   Q14 - Channel ROI
   ========================================================= */

SELECT
    ch.ChannelID,
    ch.ChannelName,
    ch.ChannelType,
    SUM(m.Impressions) AS Impressions,
    SUM(m.Clicks) AS Clicks,
    SUM(m.Conversions) AS Conversions,
    SUM(m.Spend) AS Spend,
    SUM(m.Revenue) AS Revenue,
    CAST(
        100.0 * SUM(m.Clicks)
        / NULLIF(SUM(m.Impressions),0)
        AS DECIMAL(10,2)
    ) AS CTRPct,
    CAST(
        SUM(m.Revenue)
        / NULLIF(SUM(m.Spend),0)
        AS DECIMAL(10,2)
    ) AS ROAS,
    CAST(
        (SUM(m.Revenue) - SUM(m.Spend))
        / NULLIF(SUM(m.Spend),0) * 100.0
        AS DECIMAL(10,2)
    ) AS ROIPct
FROM dbo.FactMarketing m
JOIN dbo.DimChannel ch
    ON m.ChannelID = ch.ChannelID
GROUP BY
    ch.ChannelID,
    ch.ChannelName,
    ch.ChannelType;



/* =========================================================
   Q15 - Customer Acquisition
   ========================================================= */
WITH AcquisitionTouch AS
(
    SELECT
        m.CustomerID,
        m.ChannelID,
        m.CampaignID,
        d.FullDate AS TouchDate,
        ROW_NUMBER() OVER
        (
            PARTITION BY m.CustomerID
            ORDER BY d.FullDate DESC, m.MarketingID DESC
        ) AS rn
    FROM dbo.FactMarketing m
    JOIN dbo.DimDate d
        ON m.DateID = d.DateID
    JOIN dbo.DimCustomer c
        ON m.CustomerID = c.CustomerID
    WHERE d.FullDate <= c.SignupDate
      AND d.FullDate >= DATEADD(DAY,-30,c.SignupDate)
),
Acquisition AS
(
    SELECT
        c.CustomerID,
        c.SignupDate,
        CASE
            WHEN a.CustomerID IS NULL
                THEN 'Organic'
            ELSE ch.ChannelName
        END AS AcquisitionChannel,
        CASE
            WHEN a.CustomerID IS NULL
                THEN NULL
            ELSE cp.CampaignName
        END AS AcquisitionCampaign
    FROM dbo.DimCustomer c
    LEFT JOIN AcquisitionTouch a
        ON c.CustomerID = a.CustomerID
       AND a.rn = 1
    LEFT JOIN dbo.DimChannel ch
        ON a.ChannelID = ch.ChannelID
    LEFT JOIN dbo.DimCampaign cp
        ON a.CampaignID = cp.CampaignID
)
SELECT
    AcquisitionChannel,
    YEAR(SignupDate) AS SignupYear,
    MONTH(SignupDate) AS SignupMonth,
    COUNT(*) AS AcquiredCustomers
FROM Acquisition
GROUP BY
    AcquisitionChannel,
    YEAR(SignupDate),
    MONTH(SignupDate);
