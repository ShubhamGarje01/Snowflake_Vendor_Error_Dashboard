# Snowflake_Vendor_Error_Dashboard

## Snowflake Gold Layer – Vendor Error Dashboard

### 📌 Project Overview

The **Vendor Error Dashboard** is a Snowflake-based data quality monitoring solution designed to identify, track, and manage vendor data quality issues in the **Gold Layer**.

It helps the **Data Governance and Semarchy MDM teams** identify invalid vendor records, review suggested corrections, and monitor unresolved data quality issues without directly modifying source data.

### 🎯 Business Objectives

- **Identify invalid and missing values** across critical vendor attributes.
- **Reduce manual data validation efforts.**
- **Provide visibility** into unresolved data quality issues.
- **Support data governance** through suggested corrections.

### ⚙️ Key Features

- **Automated Data Quality Monitoring:** Built a Snowflake dashboard to identify and monitor vendor data quality issues across 25+ attributes in the actual project.
- **Missing & Invalid Value Detection:** Detects missing values and invalid entries across critical vendor attributes.
- **Automated Error Detection:** Uses Snowflake Stored Procedures and Scheduled Tasks to automate error detection and dashboard refresh.
- **Dynamic Error Management:** Automatically removes resolved error records during each refresh while retaining unresolved issues for follow-up.
- **Suggested Corrections:** Provides suggested corrections to help the Data Governance Team resolve data quality issues efficiently.
- **Reduced Manual Effort:** Reduced manual error identification time from 4.5+ hours to nearly zero.
- **Operational Efficiency:** Reduced manual intervention for the team to nearly zero.

### 📊 Implementation Scope

- **Actual Project:** Implemented data quality validations across 25+ vendor attributes.
- **GitHub Demo Version:** Implemented a sample version covering 6 vendor attributes to demonstrate the core functionality.
- **Note:** The GitHub version is a simplified demonstration of the actual project implementation.

### 📊 Dashboard Preview

![Vendor Error Dashboard](screenshots/vendor_error_dashboard.png)
