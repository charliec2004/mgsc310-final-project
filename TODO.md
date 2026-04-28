# Mini AI Project; Outstanding TODOs

Sections 1-4 (team roles, reflection answers, rebuild + re-verify, pre-flight checks) are all complete and removed. Only one task left.

## 1. Submit

- [ ] Upload `app/TeamMoney_app.R` and `app/TeamMoney_Mini_AI_Report.html` to Canvas. Two files. Not a zip.

## Files of record (read-only; no edits expected)

- `app/AI-plan.md`; design spec, the source of truth for what we built and why.
- `app/TeamMoney_app.R`; working Shiny app. Implementation complete.
- `app/TeamMoney_Mini_AI_Report.qmd` + `.html`; rendered report (the `.html` is what gets submitted).
- `app/data/`; dev-only symlink to `../data` (gitignored).
- `.gitignore`; already excludes `.env`, `app/data`, `.DS_Store`.
- `~/.claude/projects/-Users-charles-Documents-CLASSES-MGSC-310-mgsc310-final-project/plans/2026-04-28-mini-ai-shiny-app.md`; the implementation plan AI followed (kept outside the repo per team direction).

## If the qmd gets edited after this point

Re-render before re-uploading:

```bash
cd /Users/charles/Documents/CLASSES/MGSC_310/mgsc310-final-project
rm -rf app/TeamMoney_Mini_AI_Report_files app/TeamMoney_Mini_AI_Report.html
quarto render app/TeamMoney_Mini_AI_Report.qmd --to html --embed-resources
```

Then re-verify the Canvas-bound HTML still has zero `[FILL IN]`, the dataset filename, the app filename, and the outcome variable.
