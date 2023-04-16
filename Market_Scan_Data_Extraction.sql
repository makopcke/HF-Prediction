USE WAREHOUSE RESEARCH;

USE DATABASE MSN;

-- Create a temporary table to hold the ICD-9 codes for heart failure
DROP TABLE IF EXISTS heart_failure_dx;
CREATE TEMPORARY TABLE heart_failure_dx (
    DX_CODE VARCHAR(7),
    DESCRIPTION VARCHAR(255)
);

INSERT INTO heart_failure_dx
VALUES
    ('398.91', 'Rheumatic heart failure (congestive)'),
    ('402.01', 'Malignant hypertensive heart disease with heart failure'),
    ('402.11', 'Benign hypertensive heart disease with heart failure'),
    ('402.91', 'Unspecified hypertensive heart disease with heart failure'),
    ('404.01', 'Hypertensive heart and chronic kidney disease, malignant, with heart failure and with chronic kidney disease stage I through stage IV, or unspecified'),
    ('404.03', 'Hypertensive heart and chronic kidney disease, malignant, with heart failure and with chronic kidney disease stage V or end stage renal disease'),
    ('404.11', 'Hypertensive heart and chronic kidney disease, benign, with heart failure and with chronic kidney disease stage I through stage IV, or unspecified'),
    ('404.13', 'Hypertensive heart and chronic kidney disease, benign, with heart failure and chronic kidney disease stage V or end stage renal disease'),
    ('404.91', 'Hypertensive heart and chronic kidney disease, unspecified, with heart failure and with chronic kidney disease stage I through stage IV, or unspecified'),
    ('404.93', 'Hypertensive heart and chronic kidney disease, unspecified, with heart failure and chronic kidney disease stage V or end stage renal disease'),
    ('428.0', 'Congestive heart failure, unspecified'),
    ('428.1', 'Left heart failure'),
    ('428.20', 'Systolic heart failure, unspecified'),
    ('428.21', 'Acute systolic heart failure'),
    ('428.22', 'Chronic systolic heart failure'),
    ('428.23', 'Acute on chronic systolic heart failure'),
    ('428.30', 'Diastolic heart failure, unspecified'),
    ('428.31', 'Acute diastolic heart failure'),
    ('428.32', 'Chronic diastolic heart failure'),
    ('428.33', 'Acute on chronic diastolic heart failure'),
    ('428.40', 'Combined systolic and diastolic heart failure, unspecified'),
    ('428.41', 'Acute combined systolic and diastolic heart failure'),
    ('428.42', 'Chronic combined systolic and diastolic heart failure'),
    ('428.43', 'Acute on chronic combined systolic and diastolic heart failure'),
    ('428.9', 'Heart failure, unspecified');
DROP TABLE IF EXISTS index_events;

CREATE TEMPORARY TABLE index_events (
    ENROLID NUMBER(38,0),
    index_date DATE
);

INSERT INTO index_events (ENROLID, index_date)
WITH heart_failure_lines AS (
    SELECT
        inpatient.ENROLID,
        inpatient.ADMDATE AS claim_date
    FROM COMMERCIAL.V_CCAE_I_SETA AS inpatient
    WHERE (AGE BETWEEN 40 AND 85)
        AND PDX IN (SELECT REPLACE(DX_CODE, '.') FROM heart_failure_dx)

    UNION ALL

    SELECT
        outpatient.ENROLID,
        outpatient.SVCDATE AS claim_date
    FROM COMMERCIAL.V_CCAE_O_SETA AS outpatient
    WHERE (AGE BETWEEN 40 AND 85)
        AND outpatient.DX1 IN (SELECT REPLACE(DX_CODE, '.') FROM heart_failure_dx)
        AND outpatient.SVCSCAT NOT IN ('22330','12330','22130','30630','10530','30330',
            '30430','31630','10230','31330','45161','45167','45164','45162','45169',
            '45163','45165','20169','45166','20269','22169','30769','10269','20166','10569') -- Diagnostic and Imaging categories
        AND outpatient.PROC1 NOT LIKE '%7____' -- Exclude imaging procedures
),
filtered_patients AS (
    SELECT
        p1.ENROLID,
        COUNT(DISTINCT p2.claim_date) AS distinct_dates
    FROM heart_failure_lines AS p1
    JOIN heart_failure_lines AS p2 ON p1.ENROLID = p2.ENROLID
    WHERE p2.claim_date BETWEEN DATEADD('year', -1, p1.claim_date) AND p1.claim_date
    GROUP BY p1.ENROLID
    HAVING COUNT(DISTINCT p2.claim_date) >= 3
),
index_dates AS (
    SELECT
        ENROLID,
        MIN(claim_date) AS index_date
    FROM heart_failure_lines
    WHERE ENROLID IN (SELECT ENROLID FROM filtered_patients)
    GROUP BY ENROLID
)
SELECT * FROM index_dates WHERE YEAR(index_date) = 2013;

DROP TABLE IF EXISTS hf_cases_claims;
CREATE TEMPORARY TABLE hf_cases_claims (
    ENROLID NUMBER(38,0),
    claim_date DATE,
    claim_type VARCHAR(2),
    MSA NUMBER(38,0),
    INDSTRY VARCHAR(1),
    AGE NUMBER(38, 0),
    SEX VARCHAR(1),
    DRG  NUMBER(38, 0),
    PROC1 VARCHAR(7),
    PDX VARCHAR(7),
    GENERID NUMBER(38, 0)
);

INSERT INTO hf_cases_claims (ENROLID, claim_date, claim_type, MSA, INDSTRY, AGE, SEX, DRG, PROC1, PDX, GENERID)
WITH date_range AS (
    SELECT
        p.ENROLID,
        p.index_date,
        DATEADD(MONTH, -18, p.index_date) AS start_date
    FROM index_events p
),
all_claims AS(
    SELECT DISTINCT
        ip.ENROLID,
        ip.YEAR,
        ip.ADMDATE AS claim_date,
        'IP' AS claim_type,
        ip.DRG,
        ip.PROC1,
        ip.PDX,
        NULL AS GENERID
    FROM COMMERCIAL.V_CCAE_I_SETA AS ip
    WHERE YEAR IN (2011, 2012, 2013) AND ip.ENROLID IN (SELECT ENROLID FROM date_range)

    UNION ALL

    SELECT DISTINCT
        op.ENROLID,
        op.YEAR,
        op.SVCDATE AS claim_date,
        'OP' AS claim_type,
        NULL,
        op.PROC1,
        op.DX1,
        NULL
    FROM COMMERCIAL.V_CCAE_O_SETA AS op
    WHERE YEAR IN (2011, 2012, 2013) AND op.ENROLID IN (SELECT ENROLID FROM date_range)

    UNION ALL

    SELECT DISTINCT
        rx.ENROLID,
        rx.YEAR,
        rx.SVCDATE AS claim_date,
        'RX' AS claim_type,
        NULL,
        NULL,
        NULL,
        rx.GENERID
    FROM COMMERCIAL.V_CCAE_D_SETA AS rx
    WHERE YEAR IN (2011, 2012, 2013) AND rx.ENROLID IN (SELECT ENROLID FROM date_range)

)
SELECT
    c.ENROLID,
    c.claim_date,
    c.claim_type,
    enrollment.MSA,
    enrollment.INDSTRY,
    enrollment.AGE,
    enrollment.SEX,
    c.DRG,
    c.PROC1,
    c.PDX,
    c.GENERID
FROM all_claims c
JOIN date_range d
    ON c.ENROLID = d.ENROLID
JOIN COMMERCIAL.V_CCAE_A_SETA enrollment
    ON c.ENROLID = enrollment.ENROLID AND c.YEAR = enrollment.YEAR
WHERE (c.claim_date BETWEEN d.start_date AND d.index_date)
    AND enrollment.INDSTRY IS NOT NULL
    AND enrollment.EGEOLOC IS NOT NULL
    AND enrollment.MSA IS NOT NULL AND enrollment.MSA != 0
    AND enrollment.AGE IS NOT NULL
    AND enrollment.SEX IS NOT NULL;



WITH heart_cases AS (
    SELECT
        ENROLID,
        MAX(claim_date) AS index_date,
        MAX(AGE) AS AGE,
        MAX(MSA) AS MSA,
        MAX(INDSTRY) AS INDSTRY,
        MAX(SEX) AS SEX
    FROM hf_cases_claims
    WHERE PDX IN (SELECT REPLACE(DX_CODE, '.') FROM heart_failure_dx)
    GROUP BY ENROLID
),
numbered_enrollment AS (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY MSA, INDSTRY, AGE, SEX
           ORDER BY ENROLID
         ) AS row_num
  FROM COMMERCIAL.V_CCAE_A_SETA
  WHERE YEAR = 2013 AND ENROLID NOT IN (SELECT ENROLID FROM heart_cases)
),
controls AS (
    SELECT hc.ENROLID AS index_enrolid,
        hc.index_date,
        DATEADD(MONTH, -18, hc.index_date) AS start_date,
        ne.ENROLID AS all_enrolid,
        ne.MSA,
        ne.INDSTRY,
        ne.AGE,
        ne.SEX
    FROM heart_cases hc
    JOIN numbered_enrollment ne
    ON hc.MSA = ne.MSA
    AND hc.INDSTRY = ne.INDSTRY
    AND hc.AGE = ne.AGE
    AND hc.SEX = ne.SEX
    WHERE ne.row_num <= 9
    ORDER BY index_enrolid, ne.row_num
),
all_claims AS(
    SELECT DISTINCT
        ip.ENROLID,
        ip.YEAR,
        ip.ADMDATE AS claim_date,
        'IP' AS claim_type,
        ip.DRG,
        ip.PROC1,
        ip.PDX,
        NULL AS GENERID
    FROM COMMERCIAL.V_CCAE_I_SETA AS ip
    WHERE YEAR IN (2011, 2012, 2013) AND ip.ENROLID IN (SELECT all_enrolid FROM controls)

    UNION ALL

    SELECT DISTINCT
        op.ENROLID,
        op.YEAR,
        op.SVCDATE AS claim_date,
        'OP' AS claim_type,
        NULL,
        op.PROC1,
        op.DX1,
        NULL
    FROM COMMERCIAL.V_CCAE_O_SETA AS op
    WHERE YEAR IN (2011, 2012, 2013) AND op.ENROLID IN (SELECT all_enrolid FROM controls)

    UNION ALL

    SELECT DISTINCT
        rx.ENROLID,
        rx.YEAR,
        rx.SVCDATE AS claim_date,
        'RX' AS claim_type,
        NULL,
        NULL,
        NULL,
        rx.GENERID
    FROM COMMERCIAL.V_CCAE_D_SETA AS rx
    WHERE YEAR IN (2011, 2012, 2013) AND rx.ENROLID IN (SELECT all_enrolid FROM controls)

)
SELECT DISTINCT
    ac.ENROLID,
    c.index_enrolid,
    ac.claim_date,
    ac.claim_type,
    c.MSA,
    c.INDSTRY,
    c.AGE,
    c.SEX,
    ac.DRG,
    ac.PROC1,
    ac.PDX,
    ac.GENERID
FROM all_claims ac
JOIN controls c
    ON ac.ENROLID = c.all_enrolid
WHERE (ac.claim_date BETWEEN c.start_date AND c.index_date);
