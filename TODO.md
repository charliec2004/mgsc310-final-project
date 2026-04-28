# Mini AI Project - Outstanding TODOs

Everything still needing to be done before submission. Tasks are grouped: human-fill-in, rebuild-and-verify, submit, optional.

## 1. Team needs to fill in (human-only)

- [x] Assign Arya's role. File: `app/README.md` line 10. File: `app/TeamMoney_Mini_AI_Report.qmd` line 22. Choices: Data Lead / Modeling Lead / App Developer / Documentation Lead.
- [x] Assign Steven's role + last name. File: `app/README.md` line 11. File: `app/TeamMoney_Mini_AI_Report.qmd` line 23.
- [x] Assign Ryan's role + last name. File: `app/README.md` line 12. File: `app/TeamMoney_Mini_AI_Report.qmd` line 24.
- [x] Sync Charlie's role across both files. `app/TeamMoney_Mini_AI_Report.qmd` line 21 and `app/README.md` line 9 both say "App Developer".

## 2. Reflection answers (human writes, AI gave recommendations)

All five live in `app/TeamMoney_Mini_AI_Report.qmd` under `# 3. Reflection`. Each currently shows a recommendation paragraph plus a `[FILL IN - your answer here]` line. Keep answers specific to this build.

- [x] Q1 - "What did AI help your group do especially well?" Replace `[FILL IN]` under `## 1. What did AI help your group do especially well?`.
- [x] Q2 - "What did AI get wrong, miss, or oversimplify?" Replace `[FILL IN]` under `## 2. What did AI get wrong, miss, or oversimplify?`.
- [ ] Q3 - "How did your group catch and fix that issue?" Replace `[FILL IN]` under `## 3. How did your group catch and fix that issue?`.
- [ ] Q4 - "What still required human judgment?" Replace `[FILL IN]` under `## 4. What still required human judgment?`.
- [x] Q5 - "If this tool were used in a real setting, what is one limitation or risk?" Replace `[FILL IN]` under `## 5. If this tool were used in a real setting, what is one limitation or risk?`.

After replacing each `[FILL IN]`, also delete the italicized recommendation blockquote above it (the `> *Recommendation: ...*` block) so the final report shows only the team's answers.

## 3. Rebuild and re-verify (after the human edits above)

- [ ] Re-render the report:

  ```bash
  cd /Users/charles/Documents/CLASSES/MGSC_310/mgsc310-final-project
  rm -rf app/TeamMoney_Mini_AI_Report_files app/TeamMoney_Mini_AI_Report.html
  quarto render app/TeamMoney_Mini_AI_Report.qmd --to html --embed-resources
  ```

  The `--embed-resources` flag is required because the template's malformed YAML doesn't pass the embed directive through automatically. Without it, the rendered HTML pulls in an external `TeamMoney_Mini_AI_Report_files/libs/` directory and the single-file submission breaks.

- [ ] Confirm no `TeamMoney_Mini_AI_Report_files/` directory exists after render: `ls app/TeamMoney_Mini_AI_Report_files 2>/dev/null && echo FAIL || echo OK`.
- [ ] Open `app/TeamMoney_Mini_AI_Report.html` in a browser. Visually confirm: Team table has all four roles filled in (no `[FILL IN]` left), all five Reflection answers are written, README/AI Build Log/Reflection sections all render.

## 4. Pre-flight before Canvas upload

Both submission files live in `app/`. There is no copy step.

- [ ] Both files exist: `ls -1 app/TeamMoney_app.R app/TeamMoney_Mini_AI_Report.html`.
- [ ] Report contains the dataset filename: `grep -F "pacific_federal_loan_campaign.csv" app/TeamMoney_Mini_AI_Report.html` returns matches.
- [ ] Report names the app file: `grep -F "TeamMoney_app.R" app/TeamMoney_Mini_AI_Report.html` returns matches.
- [ ] Report names the outcome variable: `grep -F "Personal_Loan" app/TeamMoney_Mini_AI_Report.html` returns matches.
- [ ] No `[FILL IN` strings remain in the rendered HTML: `grep -F -c "FILL IN" app/TeamMoney_Mini_AI_Report.html` should return `0`.
- [ ] No zip file in the repo: `find . -name '*.zip' -not -path './.git/*' 2>/dev/null` should return nothing.

## 5. Submit

- [ ] Charlie says "commit" (or commits manually). Per project rule, AI does not commit; team controls history on `feat/shiny-app`.
- [ ] Decide whether to merge `feat/shiny-app` into `main` or leave it on the branch. Team decides.
- [ ] Upload `app/TeamMoney_app.R` and `app/TeamMoney_Mini_AI_Report.html` to Canvas. Two files. Not a zip.

## 6. Optional / stretch (rubric does not require)

- [ ] Run `/security-review` on `app/TeamMoney_app.R` and document the result inline in the AI Build Log (currently the log mentions debug stories but not a security pass).
- [ ] Deploy to shinyapps.io. Not required by the rubric. Would require a free shinyapps.io account and `rsconnect::deployApp("app")`.
- [ ] Return to a richer model (random forest) for the final project report - currently flagged in `app/TeamMoney_Mini_AI_Report.qmd` "Simplifications and Known Issues" as future work.

## Files of record (read-only - no edits expected)

- `app/AI-plan.md` - design spec, the source of truth for what we built and why.
- `app/TeamMoney_app.R` - working Shiny app. Implementation complete.
- `app/data/` - dev-only symlink to `../data` (gitignored).
- `.gitignore` - already excludes `.env`, `app/data`, `.DS_Store`.
- `~/.claude/projects/-Users-charles-Documents-CLASSES-MGSC-310-mgsc310-final-project/plans/2026-04-28-mini-ai-shiny-app.md` - the implementation plan AI followed (kept outside the repo per Charlie's direction).
