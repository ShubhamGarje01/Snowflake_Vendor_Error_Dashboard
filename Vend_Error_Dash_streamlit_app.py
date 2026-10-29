
import streamlit as st
import pandas as pd
from datetime import datetime
from snowflake.snowpark.context import get_active_session

# --------------------------------------------------
# 1. PAGE CONFIGURATION
# --------------------------------------------------
st.set_page_config(
    page_title="Snowflake Gold Layer Error Dashboard",
    page_icon="❄️",
    layout="wide"
)

session = get_active_session()

SUMMARY_VIEW = "PRACTICE_DB.ERROR_REPORTS.VW_VENDOR_ERROR_SUMMARY"
DETAILS_VIEW = "PRACTICE_DB.ERROR_REPORTS.VW_VENDOR_ERROR_DETAILS"

TRACKED_COLUMNS = [
    "PAYMENT_TERM",
    "IMPORT_EXPORT",
    "VENDOR_STATUS",
    "VEND_TIER_GROUP",
    "Primary_Address",
    "Primary_Contact"
]

# --------------------------------------------------
# 2. HIGHLIGHT EXPORT CSV BUTTON
# --------------------------------------------------
st.markdown(
    """
    <style>
    div.stDownloadButton > button {
        background-color: #F0F0F0;
        color: #333333;
        font-weight: 600;
        border: 1px solid #D0D0D0;
        border-radius: 8px;
        padding: 0.55rem 1rem;
    }

    div.stDownloadButton > button:hover {
        background-color: #E2E2E2;
        color: #222222;
        border-color: #BDBDBD;
    }

    div.stDownloadButton > button:disabled {
        background-color: #F5F5F5;
        color: #AAAAAA;
        border-color: #E0E0E0;
    }
    </style>
    """,
    unsafe_allow_html=True
)

# --------------------------------------------------
# 3. DASHBOARD HEADER
# --------------------------------------------------
st.title("❄️ Snowflake Gold Layer Error Dashboard")

st.caption(
    "Vendor Data Quality Monitoring | Snowflake Gold Layer"
)

st.markdown(
    "**Dashboard for:** Data Governance Team · Semarchy MDM Team"
)

st.info(
    "**Purpose:** Identify vendor records that may not meet "
    "downstream consumption requirements. Use the suggested "
    "actions to investigate and correct data through approved "
    "source-system processes. This dashboard is read-only."
)

# --------------------------------------------------
# 4. LOAD DASHBOARD DATA
# --------------------------------------------------
try:
    summary = session.sql(
        f"""
        SELECT *
        FROM {SUMMARY_VIEW}
        ORDER BY ERROR_COUNT DESC
        """
    ).to_pandas()

    details = session.sql(
        f"""
        SELECT *
        FROM {DETAILS_VIEW}
        ORDER BY DETECTED_AT DESC
        """
    ).to_pandas()

except Exception as e:
    st.error("Unable to load dashboard data.")
    st.code(str(e))
    st.stop()

st.caption(
    "Dashboard queried at: "
    + datetime.now().strftime("%d %b %Y, %I:%M:%S %p")
)

# --------------------------------------------------
# 5. SUMMARY METRICS
# --------------------------------------------------
total_errors = len(details)

affected_vendors = (
    details["VENDOR_ID"].nunique()
    if not details.empty
    else 0
)

error_types = (
    details["ERROR_CODE"].nunique()
    if not details.empty
    else 0
)

c1, c2, c3 = st.columns(3)

c1.metric("Total Current Errors", total_errors)
c2.metric("Affected Vendors", affected_vendors)
c3.metric("Error Types", error_types)

# --------------------------------------------------
# 6. ERRORS BY COLUMN CHART
# --------------------------------------------------
st.divider()
st.subheader("Errors by Column")

if not summary.empty:
    chart_data = (
        summary.groupby("COLUMN_NAME")["ERROR_COUNT"]
        .sum()
        .reindex(TRACKED_COLUMNS, fill_value=0)
    )
else:
    chart_data = pd.Series(
        0,
        index=TRACKED_COLUMNS,
        dtype="int64"
    )

chart_data.index.name = "Column"

_, chart_col, _ = st.columns([1, 2, 1])

with chart_col:
    st.bar_chart(
        chart_data,
        height=300,
        color="#FFB000",
        use_container_width=True
    )

# --------------------------------------------------
# 7. ERROR DETAILS AND FILTER
# --------------------------------------------------
st.divider()
st.subheader("Error Details")

selected_column = st.selectbox(
    "Filter errors by column",
    ["All"] + TRACKED_COLUMNS
)

filtered = details.copy()

if selected_column != "All" and not filtered.empty:
    filtered = filtered[
        filtered["COLUMN_NAME"] == selected_column
    ]

# --------------------------------------------------
# 8. EXPORT FILTERED ERRORS TO CSV
# --------------------------------------------------
st.subheader("Export Error Records")

export_df = filtered.copy()

if not export_df.empty and "DETECTED_AT" in export_df.columns:
    export_df["DETECTED_AT"] = (
        export_df["DETECTED_AT"].astype(str)
    )

csv_data = export_df.to_csv(index=False).encode("utf-8")

if selected_column == "All":
    export_filename = "snowflake_gold_layer_errors_all.csv"
else:
    export_filename = (
        "snowflake_gold_layer_errors_"
        f"{selected_column.lower()}.csv"
    )

col_info, col_button = st.columns([2, 1])

with col_info:
    st.caption(
        f"Selected filter: {selected_column} | "
        f"Records to export: {len(export_df)}"
    )

with col_button:
    st.download_button(
        label="📥 Export CSV",
        data=csv_data,
        file_name=export_filename,
        mime="text/csv",
        disabled=export_df.empty,
        use_container_width=True
    )

# --------------------------------------------------
# 9. DISPLAY ERROR RECORDS
# --------------------------------------------------
st.dataframe(
    filtered,
    use_container_width=True,
    hide_index=True
)

if filtered.empty:
    st.success("No errors found for the selected filter.")

# --------------------------------------------------
# 10. FOOTER
# --------------------------------------------------
st.divider()

st.caption(
    "Audience: Data Governance and Semarchy MDM | "
    "Layer: Snowflake Gold | "
    "Error handling: Current unresolved errors only"
)

st.caption(
    "CSV exports contain the records currently returned by "
    "the dashboard views. They do not include resolved "
    "historical errors."
)
