# Bunyan Furnished — release rules

Before every publish/push of `rental-tracker.html`:

1. `python3 tools/sync.py rental-tracker.html` (writes docs/index.html, docs/c, docs/h)
2. `node tools/check.js /home/claude/bunyan-data2/book.json` — full-app regression check:
   syntax of all scripts, the 3 builds boot clean, every tab renders in every group with the real data,
   accounting self-test, key numbers (cash/profit/rent/equity per group) unchanged vs `tools/baseline.json`,
   language switch doesn't hang, no stray UI.
   - Must print `ALL GOOD`. Fix anything red before releasing.
   - If a number change is intended (an accounting rule changed on purpose), re-run with `ACCEPT=1` and say so in the commit.
   - New data in book.json => a new baseline is saved automatically.
3. Commit + push main, publish the artifact, open it.
