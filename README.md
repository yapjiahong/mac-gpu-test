# mac-gpu-test


1. 掃最近的 GPU 錯誤,看是哪些 process 造成的

log show --last 2h --predicate 'eventMessage CONTAINS[c] "gpu"' 2>/dev/null \
  | grep -iE "error|hang|restart|ignored|timeout" \
  | awk '{print $4}' | sort | uniq -c | sort -rn | head -20

這會統計每個 process 出錯的次數。如果錯誤集中在一兩個 app → 軟體問題;分散在很多 process → 較可能硬體/驅動問題。

2. 看實際錯誤內容(前 50 筆)

log show --last 2h --predicate 'eventMessage CONTAINS[c] "gpu"' 2>/dev/null \
  | grep -iE "error|hang|restart|ignored" | head -50

3. 檢查有沒有 GPU 相關的當機報告

ls -lt ~/Library/Logs/DiagnosticReports/ /Library/Logs/DiagnosticReports/ 2>/dev/null | head -30

留意  .gpuRestart 、 .panic 、 .shutdownStall  這類檔名 — 出現  gpuRestart  或  panic  是比較嚴重的信號。

4. 即時監看(跑著它,然後去操作會出錯的情境)

log stream --predicate 'eventMessage CONTAINS[c] "gpu"' | grep -iE "error|hang|ignored"