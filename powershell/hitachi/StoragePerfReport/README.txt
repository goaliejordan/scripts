version 1.0

This script uses Hitachi tuning manager to poll for performance data of certain KPI within the array. That data is then graphed
and emailed as a pdf to my team each day.

Run from current storage server to email a pdf report with graphed storage performance for the previous 24 hours.
Uses Hitachi tuning manager XML templates, RRD graphing, convert.exe, and powershell to create the reports.
Report is set to run through OS scheduler and are kept to use for trending.
daily_report.ps1 can be invoked to run all reports, or they can be invoked individually.
log files are stored in variable location.
PDF reports on the server are only stored for 30 days to ensure adequate drive space.

For questions or comments please email me: jordan.smith@cableone.biz