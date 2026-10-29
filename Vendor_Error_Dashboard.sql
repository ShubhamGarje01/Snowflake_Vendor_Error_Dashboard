use practice_db;
create schema error_reports;

--- creating tables 
CREATE OR REPLACE TABLE VENDOR (
    VENDOR_ID       NUMBER,
    VENDOR_NAME     VARCHAR(100),
    CONTACT_NAME    VARCHAR(100),
    EMAIL           VARCHAR(150),
    PHONE           VARCHAR(20),
    ADDRESS         VARCHAR(200),
    CITY            VARCHAR(50),
    STATE           VARCHAR(50),
    COUNTRY         VARCHAR(50),
    POSTAL_CODE     VARCHAR(15),
    PAYMENT_TERM    VARCHAR(10),
    IMPORT_EXPORT   VARCHAR(1),
    VENDOR_STATUS   VARCHAR(20),
    CREATED_DATE    DATE,
    UPDATED_DATE    TIMESTAMP_NTZ
);


---- above table contains the normal record, creating new record to store the invalid / error records.

CREATE OR REPLACE TABLE ERROR_RECORDS (
    VENDOR_ID       NUMBER,
    VENDOR_NAME     VARCHAR(100),
    COLUMN_NAME     VARCHAR(50),
    INVALID_VALUE   VARCHAR(200),
    ERROR_CODE      VARCHAR(50),
    ERROR_MESSAGE   VARCHAR(500),
    DETECTED_AT     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);



ALTER TABLE ERROR_RECORDS ADD COLUMN
    EXPECTED_VALUES VARCHAR(500);

ALTER TABLE ERROR_RECORDS ADD COLUMN
    SUGGESTED_ACTION VARCHAR(500);




CREATE OR REPLACE PROCEDURE SP_REFRESH_VENDOR_ERRORS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

    -- STEP 1: Create a fresh snapshot of current errors
    CREATE OR REPLACE TEMPORARY TABLE TMP_VENDOR_ERRORS AS

    SELECT
        VENDOR_ID,
        VENDOR_NAME,
        'PAYMENT_TERM' AS COLUMN_NAME,
        PAYMENT_TERM AS INVALID_VALUE,
        'INVALID_PAYMENT_TERM' AS ERROR_CODE,
        'Payment term is missing or invalid' AS ERROR_MESSAGE,
        '10_C, 20_M, 30_B, 40_I' AS EXPECTED_VALUES,
        'Verify the correct payment term with the business owner'
            AS SUGGESTED_ACTION
    FROM VENDOR
    WHERE PAYMENT_TERM IS NULL
       OR PAYMENT_TERM NOT IN ('10_C', '20_M', '30_B', '40_I')

    UNION ALL

    SELECT
        VENDOR_ID,
        VENDOR_NAME,
        'IMPORT_EXPORT',
        IMPORT_EXPORT,
        'INVALID_IMPORT_EXPORT',
        'Import/export classification is missing or invalid',
        'I, B, C, M',
        'Verify the correct vendor classification with the business owner'
    FROM VENDOR
    WHERE IMPORT_EXPORT IS NULL
       OR IMPORT_EXPORT NOT IN ('I', 'B', 'C', 'M')

    UNION ALL

    SELECT
        VENDOR_ID,
        VENDOR_NAME,
        'VENDOR_STATUS',
        VENDOR_STATUS,
        'INVALID_VENDOR_STATUS',
        'Vendor status is missing or invalid',
        'ACTIVE, INACTIVE',
        'Confirm the correct vendor status with the business owner'
    FROM VENDOR
    WHERE VENDOR_STATUS IS NULL
       OR VENDOR_STATUS NOT IN ('ACTIVE', 'INACTIVE');


    -- STEP 2: Synchronize existing and new errors
    BEGIN TRANSACTION;

    MERGE INTO ERROR_RECORDS T
    USING TMP_VENDOR_ERRORS S
       ON T.VENDOR_ID = S.VENDOR_ID
      AND T.ERROR_CODE = S.ERROR_CODE

    WHEN MATCHED THEN UPDATE SET
        T.VENDOR_NAME      = S.VENDOR_NAME,
        T.COLUMN_NAME      = S.COLUMN_NAME,
        T.INVALID_VALUE    = S.INVALID_VALUE,
        T.ERROR_MESSAGE    = S.ERROR_MESSAGE,
        T.EXPECTED_VALUES  = S.EXPECTED_VALUES,
        T.SUGGESTED_ACTION = S.SUGGESTED_ACTION

    WHEN NOT MATCHED THEN INSERT (
        VENDOR_ID,
        VENDOR_NAME,
        COLUMN_NAME,
        INVALID_VALUE,
        ERROR_CODE,
        ERROR_MESSAGE,
        DETECTED_AT,
        EXPECTED_VALUES,
        SUGGESTED_ACTION
    )
    VALUES (
        S.VENDOR_ID,
        S.VENDOR_NAME,
        S.COLUMN_NAME,
        S.INVALID_VALUE,
        S.ERROR_CODE,
        S.ERROR_MESSAGE,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        S.EXPECTED_VALUES,
        S.SUGGESTED_ACTION
    );


    -- STEP 3: Remove errors resolved in the source data
    DELETE FROM ERROR_RECORDS T
    WHERE NOT EXISTS (
        SELECT 1
        FROM TMP_VENDOR_ERRORS S
        WHERE S.VENDOR_ID = T.VENDOR_ID
          AND S.ERROR_CODE = T.ERROR_CODE
    );

    COMMIT;


    -- STEP 4: Drop the temporary snapshot
    DROP TABLE IF EXISTS TMP_VENDOR_ERRORS;

    RETURN 'Vendor error refresh completed successfully';

EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        DROP TABLE IF EXISTS TMP_VENDOR_ERRORS;
        RAISE;
END;
$$;




SELECT *
FROM ERROR_RECORDS
ORDER BY VENDOR_ID, COLUMN_NAME;  --- 0 records


CALL SP_REFRESH_VENDOR_ERRORS();



--- summurizrd view
CREATE OR REPLACE VIEW VW_VENDOR_ERROR_SUMMARY AS
SELECT
    COLUMN_NAME,
    ERROR_CODE,
    ERROR_MESSAGE,
    COUNT(*) AS ERROR_COUNT
FROM ERROR_RECORDS
GROUP BY
    COLUMN_NAME,
    ERROR_CODE,
    ERROR_MESSAGE;


select * from VW_VENDOR_ERROR_SUMMARY;


--- detailed error view 
CREATE OR REPLACE VIEW VW_VENDOR_ERROR_DETAILS AS
SELECT
    VENDOR_ID,
    VENDOR_NAME,
    COLUMN_NAME,
    INVALID_VALUE,
    ERROR_CODE,
    ERROR_MESSAGE,
    EXPECTED_VALUES,
    SUGGESTED_ACTION,
    DETECTED_AT
FROM ERROR_RECORDS;



select * from VW_VENDOR_ERROR_DETAILS;


SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_ROLE();




select * from VENDOR;

/*
update vendor
set vendor_status = 'Not Vendor'
where vendor_id in (2, 5, 10, 17, 25);


update vendor 
set payment_term = '50_ID'
where vendor_id in (30, 26, 21);
*/




CALL SP_REFRESH_VENDOR_ERRORS(); --- make above changes, so there should be error records in each category.

select * from VENDOR;



--- making modifications, adding few more error columns and adding new logic, one vendor should have atleast one primary address & primary contact, if not then that will be displayed under primary_address or primary_contact column in error dashboard. with this we are adding new column to vendor table : vend_tier_group, it have specific values in it, which are allowed in downstream system. now if any other values given by MDM team for this attribute may result in logical error, so it will be shown on error dashboard.

-- Add the new vendor tier column.
ALTER TABLE VENDOR
ADD COLUMN IF NOT EXISTS VEND_TIER_GROUP VARCHAR(50);


-- Create the vendor address table.
CREATE TABLE IF NOT EXISTS VEND_ADDRESS (
    ADDRESS_ID       NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    VENDOR_ID        NUMBER NOT NULL,
    ADDRESS_LINE_1  VARCHAR(200),
    ADDRESS_LINE_2  VARCHAR(200),
    CITY             VARCHAR(100),
    STATE            VARCHAR(100),
    COUNTRY          VARCHAR(100),
    POSTAL_CODE      VARCHAR(30),
    IS_PRIMARY       BOOLEAN DEFAULT FALSE,
    CREATED_AT       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create the vendor contact table.
CREATE TABLE IF NOT EXISTS VEND_CONTACT (
    CONTACT_ID       NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    VENDOR_ID        NUMBER NOT NULL,
    CONTACT_NAME     VARCHAR(150),
    EMAIL            VARCHAR(254),
    PHONE            VARCHAR(50),
    IS_PRIMARY       BOOLEAN DEFAULT FALSE,
    CREATED_AT       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

select * from ERROR_RECORDS;



--- adding new logic into existing store procedure for new additional 3 columns, and re-creating it 

CREATE OR REPLACE PROCEDURE SP_REFRESH_VENDOR_ERRORS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

    -- Operation 1: Build the complete current-error snapshot.
    CREATE OR REPLACE TEMPORARY TABLE TMP_VENDOR_ERRORS AS

    -- 1. PAYMENT_TERM
    SELECT
        VENDOR_ID,
        VENDOR_NAME,
        'PAYMENT_TERM' AS COLUMN_NAME,
        COALESCE(PAYMENT_TERM, '<NULL>') AS INVALID_VALUE,
        'INVALID_PAYMENT_TERM' AS ERROR_CODE,
        'Payment term is missing or invalid' AS ERROR_MESSAGE,
        '10_C, 20_M, 30_B, 40_I' AS EXPECTED_VALUES,
        'Verify the correct payment term with the business owner'
            AS SUGGESTED_ACTION
    FROM VENDOR
    WHERE PAYMENT_TERM IS NULL
       OR PAYMENT_TERM NOT IN ('10_C', '20_M', '30_B', '40_I')

    UNION ALL

    -- 2. IMPORT_EXPORT
    SELECT
        VENDOR_ID,
        VENDOR_NAME,
        'IMPORT_EXPORT',
        COALESCE(IMPORT_EXPORT, '<NULL>'),
        'INVALID_IMPORT_EXPORT',
        'Import/export classification is missing or invalid',
        'I, B, C, M',
        'Verify the correct vendor classification with the business owner'
    FROM VENDOR
    WHERE IMPORT_EXPORT IS NULL
       OR IMPORT_EXPORT NOT IN ('I', 'B', 'C', 'M')

    UNION ALL

    -- 3. VENDOR_STATUS
    SELECT
        VENDOR_ID,
        VENDOR_NAME,
        'VENDOR_STATUS',
        COALESCE(VENDOR_STATUS, '<NULL>'),
        'INVALID_VENDOR_STATUS',
        'Vendor status is missing or invalid',
        'ACTIVE, INACTIVE',
        'Confirm the correct vendor status with the business owner'
    FROM VENDOR
    WHERE VENDOR_STATUS IS NULL
       OR VENDOR_STATUS NOT IN ('ACTIVE', 'INACTIVE')

    UNION ALL

    -- 4. VEND_TIER_GROUP
    SELECT
        VENDOR_ID,
        VENDOR_NAME,
        'VEND_TIER_GROUP',
        COALESCE(VEND_TIER_GROUP, '<NULL>'),
        'INVALID_VEND_TIER_GROUP',
        'Vendor tier group is missing or invalid',
        'Titan, Other, Carporate, Business, Legal',
        'Confirm the correct tier group with the business owner'
    FROM VENDOR
    WHERE VEND_TIER_GROUP IS NULL
       OR VEND_TIER_GROUP NOT IN (
           'Titan', 'Other', 'Carporate', 'Business', 'Legal'
       )

    UNION ALL

    -- 5. Primary address validation
    SELECT
        V.VENDOR_ID,
        V.VENDOR_NAME,
        'Primary_Address',
        TO_VARCHAR(COUNT_IF(A.IS_PRIMARY = TRUE)),
        'INVALID_PRIMARY_ADDRESS',
        CASE
            WHEN COUNT_IF(A.IS_PRIMARY = TRUE) = 0
                THEN 'Vendor has no primary address'
            ELSE 'Vendor has multiple primary addresses'
        END,
        'Exactly one primary address',
        'Set exactly one valid vendor address as primary'
    FROM VENDOR V
    LEFT JOIN VEND_ADDRESS A
        ON V.VENDOR_ID = A.VENDOR_ID
    GROUP BY V.VENDOR_ID, V.VENDOR_NAME
    HAVING COUNT_IF(A.IS_PRIMARY = TRUE) <> 1

    UNION ALL

    -- 6. Primary contact validation
    SELECT
        V.VENDOR_ID,
        V.VENDOR_NAME,
        'Primary_Contact',
        TO_VARCHAR(COUNT_IF(C.IS_PRIMARY = TRUE)),
        'INVALID_PRIMARY_CONTACT',
        CASE
            WHEN COUNT_IF(C.IS_PRIMARY = TRUE) = 0
                THEN 'Vendor has no primary contact'
            ELSE 'Vendor has multiple primary contacts'
        END,
        'Exactly one primary contact',
        'Set exactly one valid vendor contact as primary'
    FROM VENDOR V
    LEFT JOIN VEND_CONTACT C
        ON V.VENDOR_ID = C.VENDOR_ID
    GROUP BY V.VENDOR_ID, V.VENDOR_NAME
    HAVING COUNT_IF(C.IS_PRIMARY = TRUE) <> 1
    ;

    -- Operation 2: Merge new and existing errors.
    BEGIN TRANSACTION;

    MERGE INTO ERROR_RECORDS T
    USING TMP_VENDOR_ERRORS S
       ON T.VENDOR_ID = S.VENDOR_ID
      AND T.ERROR_CODE = S.ERROR_CODE

    WHEN MATCHED THEN UPDATE SET
        T.VENDOR_NAME      = S.VENDOR_NAME,
        T.COLUMN_NAME      = S.COLUMN_NAME,
        T.INVALID_VALUE    = S.INVALID_VALUE,
        T.ERROR_MESSAGE    = S.ERROR_MESSAGE,
        T.EXPECTED_VALUES  = S.EXPECTED_VALUES,
        T.SUGGESTED_ACTION = S.SUGGESTED_ACTION

    WHEN NOT MATCHED THEN INSERT (
        VENDOR_ID,
        VENDOR_NAME,
        COLUMN_NAME,
        INVALID_VALUE,
        ERROR_CODE,
        ERROR_MESSAGE,
        DETECTED_AT,
        EXPECTED_VALUES,
        SUGGESTED_ACTION
    )
    VALUES (
        S.VENDOR_ID,
        S.VENDOR_NAME,
        S.COLUMN_NAME,
        S.INVALID_VALUE,
        S.ERROR_CODE,
        S.ERROR_MESSAGE,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        S.EXPECTED_VALUES,
        S.SUGGESTED_ACTION
    );

    -- Operation 3: Remove errors resolved since the last refresh.
    DELETE FROM ERROR_RECORDS T
    WHERE NOT EXISTS (
        SELECT 1
        FROM TMP_VENDOR_ERRORS S
        WHERE S.VENDOR_ID = T.VENDOR_ID
          AND S.ERROR_CODE = T.ERROR_CODE
    );

    COMMIT;

    -- Operation 4: Clean up the temporary snapshot.
    DROP TABLE IF EXISTS TMP_VENDOR_ERRORS;

    RETURN 'Vendor error refresh completed successfully';

EXCEPTION
    WHEN OTHER THEN
        RAISE;
END;
$$;


---- testing the store procedure as dry run 

CALL PRACTICE_DB.ERROR_REPORTS.SP_REFRESH_VENDOR_ERRORS();



SELECT
    COLUMN_NAME,
    ERROR_CODE,
    COUNT(*) AS ERROR_COUNT
FROM PRACTICE_DB.ERROR_REPORTS.ERROR_RECORDS
GROUP BY COLUMN_NAME, ERROR_CODE
ORDER BY COLUMN_NAME;

select * from vendor
order by vendor_id;




------ updating vend_tier_group column 

UPDATE PRACTICE_DB.ERROR_REPORTS.VENDOR
SET VEND_TIER_GROUP = CASE
    WHEN VENDOR_ID IN (3, 5, 7, 9, 12, 15, 18, 21, 24, 27) THEN
        CASE VENDOR_ID
            WHEN 3  THEN 'Titan'
            WHEN 5  THEN 'Titan'
            WHEN 7  THEN 'Other'
            WHEN 9  THEN 'Other'
            WHEN 12 THEN 'Carporate'
            WHEN 15 THEN 'Carporate'
            WHEN 18 THEN 'Business'
            WHEN 21 THEN 'Business'
            WHEN 24 THEN 'Legal'
            WHEN 27 THEN 'Legal'
        END
    WHEN VENDOR_ID IN (10, 17, 28, 29) THEN 'Invalid'
    ELSE 'Titan'
END
WHERE VENDOR_ID BETWEEN 1 AND 30;



SELECT * FROM VENDOR;



--- NEED TO RUN THE STORE PROCEDURE TO PROCESS THE LATEST DATA 

CALL PRACTICE_DB.ERROR_REPORTS.SP_REFRESH_VENDOR_ERRORS();