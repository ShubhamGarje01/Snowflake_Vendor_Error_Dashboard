
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(
    page_title="Vendor Data Quality Dashboard - Data Governance Team",
    layout="wide"
)

st.title("Vendor Data Quality Dashboard")
st.caption("Current validation errors | Read-only governance view")

session = get_active_session()

# Fully qualified Snowflake view names
SUMMARY_VIEW = "PRACTICE_DB.ERROR_REPORTS.VW_VENDOR_ERROR_SUMMARY"
DETAILS_VIEW = "PRACTICE_DB.ERROR_REPORTS.VW_VENDOR_ERROR_DETAILS"

# Load dashboard data
try:
    summary = session.sql(f"""
        SELECT *
        FROM {SUMMARY_VIEW}
        ORDER BY ERROR_COUNT DESC
    """).to_pandas()

    details = session.sql(f"""
        SELECT *
        FROM {DETAILS_VIEW}
        ORDER BY DETECTED_AT DESC
    """).to_pandas()

except Exception as e:
    st.error("Unable to load dashboard data.")
    st.code(str(e))
    st.info(
        "Verify that both views exist in "
        "PRACTICE_DB.ERROR_REPORTS and that the app role "
        "has permission to access them."
    )
    st.stop()

# KPI cards
total_errors = len(details)
affected_vendors = (
    details["VENDOR_ID"].nunique()
    if not details.empty else 0
)
error_types = (
    details["ERROR_CODE"].nunique()
    if not details.empty else 0
)

col1, col2, col3 = st.columns(3)

col1.metric("Total Errors", total_errors)
col2.metric("Affected Vendors", affected_vendors)
col3.metric("Error Types", error_types)

st.divider()

# Chart

# Error summary chart

# Error summary chart
st.subheader("Errors by Column")

# Always display all three validation columns
tracked_columns = [
    "PAYMENT_TERM",
    "IMPORT_EXPORT",
    "VENDOR_STATUS"
]

if not summary.empty:
    chart_data = (
        summary.groupby("COLUMN_NAME")["ERROR_COUNT"]
        .sum()
        .reindex(tracked_columns, fill_value=0)
        .rename_axis("Column")
    )

    # Compact, centered chart
    _, chart_col, _ = st.columns([1, 2, 1])

    with chart_col:
        st.bar_chart(
            chart_data,
            height=250,
            color="#FFB000",
            use_container_width=True
        )

else:
    st.info("No current data quality errors.")

st.divider()

# Error details with filter
st.subheader("Error Details")

if not details.empty:
    selected_column = st.selectbox(
        "Filter by column",
        ["All"] + tracked_columns
    )

    filtered = details.copy()

    if selected_column != "All":
        filtered = filtered[
            filtered["COLUMN_NAME"] == selected_column
        ]

    st.dataframe(
        filtered,
        use_container_width=True,
        hide_index=True
    )

    st.caption(
        "Correct errors through the approved source-system process. "
        "This dashboard does not modify vendor records."
    )
else:
    st.success("No unresolved vendor errors.")
