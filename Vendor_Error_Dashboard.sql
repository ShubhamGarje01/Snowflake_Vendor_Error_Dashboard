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