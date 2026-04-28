# Team Money - Mini AI Project (working README)

This is the team's working README for the `app/` directory. It is **not** the README that gets graded - that one lives inside `Mini_AI_Report.qmd`. Use this file to coordinate during the build; copy whatever's relevant into the report's README section at submission time.

## Team

| Member | Role |
|---|---|
| Charlie Conner | App Developer |
| Arya Kumar | _[FILL IN]_ |
| Steven _[last name]_ | _[FILL IN]_ |
| Ryan _[last name]_ | _[FILL IN]_ |

> **Action item:** Charlie will assign roles. Once filled in here, copy the same table into the README section of `Mini_AI_Report.qmd` so the rendered report contains it (rubric requires team roles in the report README, not just locally).

## Files in this directory

| File | What it is |
|---|---|
| `app.R` | The Shiny app. At submission, gets copied to `../TeamMoney_app.R`. |
| `Mini_AI_Report.qmd` | The Quarto report (README + AI Build Log + Reflection). Renders to `Mini_AI_Report.html`, then copied to `../TeamMoney_Mini_AI_Report.html` at submission. |
| `AI-plan.md` | The full design spec - what we're building and why. Read this first. |
| `README.md` | This file. |

## Dataset

The app expects `../data/pacific_federal_loan_campaign.csv` (relative to `app.R`). Don't move it.

For development, there is a symlink at `app/data → ../data` (gitignored) so that `shiny::runApp("app/app.R")` can find the dataset without needing the dataset to be duplicated.

## Run the app (dev server)

From the **repo root**:

```bash
Rscript -e 'shiny::runApp("app/app.R", port = 7654, launch.browser = FALSE)'
```

Then open <http://127.0.0.1:7654>. Press `Ctrl+C` to stop. Drop `launch.browser = FALSE` to have it open your default browser automatically. Drop the port to let Shiny pick one.

In RStudio: open `app.R` and click **Run App**.

## Render the report

```bash
quarto render app/Mini_AI_Report.qmd --to html --embed-resources
```

The `--embed-resources` flag is required because the template's malformed YAML doesn't get the embed directive applied automatically - without it, the rendered HTML pulls in an external `_files/libs/` folder and the single-file submission breaks.

## Submission packaging

```bash
cp app/app.R TeamMoney_app.R
cp app/Mini_AI_Report.html TeamMoney_Mini_AI_Report.html
```

Then run the pre-flight check from `AI-plan.md` §11 step 4.

## Build status

Implementation complete. App runs cleanly, report renders cleanly, submission files copied to repo root and pre-flight passes. Awaiting team review and Charlie's go-ahead to commit.
