# monitoring/drift_monitor.py
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset

def run_drift_monitor(ref_df, prod_df):
    report = Report(metrics=[DataDriftPreset()])
    report.run(reference_data=ref_df, current_data=prod_df)
    report.save_html("drift_report.html")
