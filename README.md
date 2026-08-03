# mac-gpu-test

log show --last 2h --predicate 'eventMessage CONTAINS[c] "gpu"' 2>/dev/null \
  | grep -iE "error|hang|restart|ignored|timeout" \
  | awk '{print $4}' | sort | uniq -c | sort -rn | head -20


log show --last 2h --predicate 'eventMessage CONTAINS[c] "gpu"' 2>/dev/null \
  | grep -iE "error|hang|restart|ignored" | head -50

ls -lt ~/Library/Logs/DiagnosticReports/ /Library/Logs/DiagnosticReports/ 2>/dev/null | head -30


log stream --predicate 'eventMessage CONTAINS[c] "gpu"' | grep -iE "error|hang|ignored"