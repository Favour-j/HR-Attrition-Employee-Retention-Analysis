CREATE DATABASE HRAttritionDB;

GO
USE HRAttritionDB;
GO

-- Create staging table matching CSV columns 
CREATE TABLE hr_raw (
    Age                      INT,
    Attrition                VARCHAR(10),
    BusinessTravel           VARCHAR(50),
    DailyRate                INT,
    Department               VARCHAR(50),
    DistanceFromHome         INT,
    Education                INT,
    EducationField           VARCHAR(50),
    EmployeeCount            INT,
    EmployeeNumber           INT PRIMARY KEY,
    EnvironmentSatisfaction  INT,
    Gender                   VARCHAR(10),
    HourlyRate               INT,
    JobInvolvement           INT,
    JobLevel                 INT,
    JobRole                  VARCHAR(50),
    JobSatisfaction          INT,
    MaritalStatus            VARCHAR(20),
    MonthlyIncome            INT,
    MonthlyRate              INT,
    NumCompaniesWorked       INT,
    Over18                   VARCHAR(5),
    OverTime                 VARCHAR(5),
    PercentSalaryHike        INT,
    PerformanceRating        INT,
    RelationshipSatisfaction INT,
    StandardHours            INT,
    StockOptionLevel         INT,
    TotalWorkingYears        INT,
    TrainingTimesLastYear    INT,
    WorkLifeBalance          INT,
    YearsAtCompany           INT,
    YearsInCurrentRole       INT,
    YearsSinceLastPromotion  INT,
    YearsWithCurrManager     INT
);

-- import the CSV using SSMS BULK INSERT
BULK INSERT hr_raw
FROM 'C:\Projects\WA_Fn-UseC_-HR-Employee-Attrition.csv'
WITH (
    FIRSTROW = 2,          -- Skip header row
    FIELDTERMINATOR = ',', -- CSV delimiter
    ROWTERMINATOR = '\n',
    TABLOCK
);

SELECT COUNT(*) AS total_rows FROM hr_raw;

-- Check for NULLs in every key column
SELECT
    SUM(CASE WHEN Attrition             IS NULL THEN 1 ELSE 0 END) AS null_attrition,
    SUM(CASE WHEN OverTime              IS NULL THEN 1 ELSE 0 END) AS null_overtime,
    SUM(CASE WHEN MonthlyIncome         IS NULL THEN 1 ELSE 0 END) AS null_income,
    SUM(CASE WHEN JobSatisfaction       IS NULL THEN 1 ELSE 0 END) AS null_jobsat,
    SUM(CASE WHEN Age                   IS NULL THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN Department            IS NULL THEN 1 ELSE 0 END) AS null_dept,
    SUM(CASE WHEN YearsAtCompany        IS NULL THEN 1 ELSE 0 END) AS null_tenure,
    SUM(CASE WHEN EnvironmentSatisfaction IS NULL THEN 1 ELSE 0 END) AS null_envsat
FROM hr_raw;

-- Check distinct values of categorical columns
SELECT DISTINCT Attrition    
FROM hr_raw;  

SELECT DISTINCT OverTime     
FROM hr_raw;  

SELECT DISTINCT Department  
FROM hr_raw;  

SELECT DISTINCT Gender    
FROM hr_raw;  

SELECT DISTINCT MaritalStatus 
FROM hr_raw; 

--Check for duplicate EmployeeNumbers
SELECT EmployeeNumber, COUNT(*) AS cnt
FROM hr_raw
GROUP BY EmployeeNumber
HAVING COUNT(*) > 1;


-- check numeric ranges
SELECT
    MIN(Age) AS min_age, MAX(Age) AS max_age,
    MIN(MonthlyIncome) AS min_income, MAX(MonthlyIncome) AS max_income,
    MIN(JobSatisfaction) AS min_sat, MAX(JobSatisfaction) AS max_sat,
    MIN(YearsAtCompany) AS min_yrs, MAX(YearsAtCompany) AS max_yrs
FROM hr_raw;

-- Check constant columns 
SELECT DISTINCT StandardHours 
FROM hr_raw;  
SELECT DISTINCT EmployeeCount 
FROM hr_raw;  
SELECT DISTINCT Over18        
FROM hr_raw;  

-- Create clean production table
CREATE TABLE hr_clean (
    EmployeeNumber           INT PRIMARY KEY,
    Age                      INT,
    AgeGroup                 VARCHAR(20), 
    Gender                   VARCHAR(10),
    MaritalStatus            VARCHAR(20),
    Department               VARCHAR(50),
    JobRole                  VARCHAR(50),
    JobLevel                 INT,
    BusinessTravel           VARCHAR(50),
    EducationField           VARCHAR(50),
    Education                INT,
        -- Satisfaction & engagement scores
    JobSatisfaction          INT,
    JobSatisfactionLabel     VARCHAR(20),   -- Engineered: Low/Medium/High/Very High
    EnvironmentSatisfaction  INT,
    RelationshipSatisfaction INT,
    WorkLifeBalance          INT,
    JobInvolvement           INT,
    PerformanceRating        INT,

    -- Compensation
    MonthlyIncome            INT,
    SalaryBand               VARCHAR(20),   -- Engineered: Low/Mid/High/Executive
    DailyRate                INT,
    HourlyRate               INT,
    MonthlyRate              INT,
    PercentSalaryHike        INT,
    StockOptionLevel         INT,

    -- Work patterns
    OverTime                 VARCHAR(5),
    OverTimeFlag             INT,           -- Engineered: 1=Yes, 0=No
    DistanceFromHome         INT,
    TravelFrequencyScore     INT,           -- Engineered from BusinessTravel

    -- Tenure & experience
    TotalWorkingYears        INT,
    YearsAtCompany           INT,
    YearsInCurrentRole       INT,
    YearsSinceLastPromotion  INT,
    YearsWithCurrManager     INT,
    NumCompaniesWorked       INT,
    TrainingTimesLastYear    INT,

    -- Target variable
    Attrition                VARCHAR(5),
    AttritionFlag            INT,           -- Engineered: 1=Yes, 0=No

    -- Risk scoring 
    AttritionRiskScore       INT,
    AttritionRiskLevel       VARCHAR(10)
);

INSERT INTO hr_clean
SELECT
    EmployeeNumber,
    Age,

    -- AGE GROUP BANDS
    CASE
        WHEN Age BETWEEN 18 AND 25 THEN '18-25'
        WHEN Age BETWEEN 26 AND 35 THEN '26-35'
        WHEN Age BETWEEN 36 AND 45 THEN '36-45'
        WHEN Age BETWEEN 46 AND 55 THEN '46-55'
        ELSE '55+'
    END AS AgeGroup,

    Gender,
    MaritalStatus,
    Department,
    JobRole,
    JobLevel,
    BusinessTravel,
    EducationField,
    Education,
    JobSatisfaction,

    -- JOB SATISFACTION LABEL 
    CASE JobSatisfaction
        WHEN 1 THEN 'Low'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'High'
        WHEN 4 THEN 'Very High'
    END AS JobSatisfactionLabel,

    EnvironmentSatisfaction,
    RelationshipSatisfaction,
    WorkLifeBalance,
    JobInvolvement,
    PerformanceRating,
    MonthlyIncome,

    -- SALARY BAND (quartile-based)
    CASE
        WHEN MonthlyIncome < 3000  THEN 'Low (<$3K)'
        WHEN MonthlyIncome < 6000  THEN 'Mid ($3K-$6K)'
        WHEN MonthlyIncome < 10000 THEN 'High ($6K-$10K)'
        ELSE 'Executive ($10K+)'
    END AS SalaryBand,

    DailyRate,
    HourlyRate,
    MonthlyRate,
    PercentSalaryHike,
    StockOptionLevel,
    OverTime,

    -- OVERTIME FLAG 
    CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END AS OverTimeFlag,

    DistanceFromHome,

    -- TRAVEL FREQUENCY SCORE 
    CASE BusinessTravel
        WHEN 'Non-Travel'        THEN 0
        WHEN 'Travel_Rarely'     THEN 1
        WHEN 'Travel_Frequently' THEN 2
    END AS TravelFrequencyScore,

    TotalWorkingYears,
    YearsAtCompany,
    YearsInCurrentRole,
    YearsSinceLastPromotion,
    YearsWithCurrManager,
    NumCompaniesWorked,
    TrainingTimesLastYear,
    Attrition,

    -- ATTRITION FLAG 
    CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END AS AttritionFlag,

    -- RISK SCORE (weighted sum of attrition drivers)
    -- Higher = more at risk. Max possible score = 13.
    (CASE WHEN OverTime = 'Yes' THEN 3 ELSE 0 END)                       -- Overtime: highest weight
  + (CASE WHEN JobSatisfaction  <= 2 THEN 2 ELSE 0 END)                  -- Low job satisfaction
  + (CASE WHEN WorkLifeBalance  <= 2 THEN 2 ELSE 0 END)                  -- Poor WLB
  + (CASE WHEN YearsAtCompany   <= 2 THEN 2 ELSE 0 END)                  -- Early tenure (flight risk)
  + (CASE WHEN MonthlyIncome    < 3000 THEN 2 ELSE 0 END)                -- Very low salary
  + (CASE WHEN NumCompaniesWorked >= 4 THEN 1 ELSE 0 END)                -- Job hopper signal
  + (CASE WHEN EnvironmentSatisfaction <= 2 THEN 1 ELSE 0 END)           -- Unhappy with environment
    AS AttritionRiskScore,
    -- RISK LEVEL 
    CASE
        WHEN
            (CASE WHEN OverTime = 'Yes' THEN 3 ELSE 0 END)
          + (CASE WHEN JobSatisfaction  <= 2 THEN 2 ELSE 0 END)
          + (CASE WHEN WorkLifeBalance  <= 2 THEN 2 ELSE 0 END)
          + (CASE WHEN YearsAtCompany   <= 2 THEN 2 ELSE 0 END)
          + (CASE WHEN MonthlyIncome    < 3000 THEN 2 ELSE 0 END)
          + (CASE WHEN NumCompaniesWorked >= 4 THEN 1 ELSE 0 END)
          + (CASE WHEN EnvironmentSatisfaction <= 2 THEN 1 ELSE 0 END)
          >= 7 THEN 'High'
        WHEN
            (CASE WHEN OverTime = 'Yes' THEN 3 ELSE 0 END)
          + (CASE WHEN JobSatisfaction  <= 2 THEN 2 ELSE 0 END)
          + (CASE WHEN WorkLifeBalance  <= 2 THEN 2 ELSE 0 END)
          + (CASE WHEN YearsAtCompany   <= 2 THEN 2 ELSE 0 END)
          + (CASE WHEN MonthlyIncome    < 3000 THEN 2 ELSE 0 END)
          + (CASE WHEN NumCompaniesWorked >= 4 THEN 1 ELSE 0 END)
          + (CASE WHEN EnvironmentSatisfaction <= 2 THEN 1 ELSE 0 END)
          >= 4 THEN 'Medium'
        ELSE 'Low'
    END AS AttritionRiskLevel

FROM hr_raw;

SELECT COUNT(*) 
FROM hr_clean;

SELECT TOP 10
    EmployeeNumber, Age, AgeGroup, MonthlyIncome, SalaryBand,
    OverTime, OverTimeFlag, Attrition, AttritionFlag,
    AttritionRiskScore, AttritionRiskLevel
FROM hr_clean
SELECT TOP 10
    EmployeeNumber, Age, AgeGroup, MonthlyIncome, SalaryBand,
    OverTime, OverTimeFlag, Attrition, AttritionFlag,
    AttritionRiskScore, AttritionRiskLevel
FROM hr_clean


SELECT TOP 10
    EmployeeNumber, Age, AgeGroup, MonthlyIncome, SalaryBand,
    OverTime, OverTimeFlag, Attrition, AttritionFlag,
    AttritionRiskScore, AttritionRiskLevel
FROM hr_clean
ORDER BY AttritionRiskScore DESC;

-- Overall attrition rate 
SELECT
    COUNT(*) AS total,
    SUM(AttritionFlag) AS left_count,
    CAST(SUM(AttritionFlag) AS FLOAT) / COUNT(*) * 100 AS attrition_rate_pct
FROM hr_clean;

-- Attrition rate by overtime group
SELECT
    OverTime,
    COUNT(*) AS headcount,
    SUM(AttritionFlag) AS attritors,
    CAST(SUM(AttritionFlag) AS FLOAT) / COUNT(*) * 100 AS attrition_rate
FROM hr_clean
GROUP BY OverTime
ORDER BY attrition_rate DESC;


-- Attrition by salary band
SELECT
    SalaryBand,
    COUNT(*) AS headcount,
    SUM(AttritionFlag) AS attritors,
    CAST(SUM(AttritionFlag) AS FLOAT) / COUNT(*) * 100 AS attrition_rate
FROM hr_clean
GROUP BY SalaryBand
ORDER BY attrition_rate DESC;

-- Attrition by department
SELECT
    Department,
    COUNT(*) AS headcount,
    SUM(AttritionFlag) AS attritors,
    CAST(SUM(AttritionFlag) AS FLOAT) / COUNT(*) * 100 AS attrition_rate
FROM hr_clean
GROUP BY Department
ORDER BY attrition_rate DESC;

-- Risk level distribution
SELECT AttritionRiskLevel, COUNT(*) AS count
FROM hr_clean
GROUP BY AttritionRiskLevel;

-- Top 20 highest-risk current employees (not already left)
SELECT TOP 20
    EmployeeNumber, Department, JobRole, Age,
    MonthlyIncome, OverTime, YearsAtCompany,
    JobSatisfaction, AttritionRiskScore, AttritionRiskLevel
FROM hr_clean
WHERE Attrition = 'No'
ORDER BY AttritionRiskScore DESC;
