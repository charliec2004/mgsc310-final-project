# Team Money: Mini AI Project (working README)

This is the team's working README for the `app/` directory. It is **not** the README that gets graded; that one lives inside `TeamMoney_Mini_AI_Report.qmd`. Use this file to coordinate during the build, and copy whatever's relevant into the report's README section at submission time.

## Team

| Member | Role |
|---|---|
| Charlie Conner | App Developer |
| Arya Kumar | Modeling Lead |
| Steven Stanos | Data Lead |
| Ryan McMillan | Documentation Lead |

## Files in this directory

| File | What it is |
|---|---|
| `TeamMoney_app.R` | The Shiny app. **Uploaded to Canvas as-is.** No copy step. |
| `TeamMoney_Mini_AI_Report.qmd` | Quarto source for the report (README + AI Build Log + Reflection). |
| `TeamMoney_Mini_AI_Report.html` | Rendered output of the .qmd. **Uploaded to Canvas as-is.** |
| `AI-plan.md` | The full design spec: what we're building and why. Read this first. |
| `README.md` | This file. |
| `data/` | Dev-only symlink to `../data/` (gitignored). Lets `shiny::runApp` find the dataset locally. The grader supplies their own `data/` next to `TeamMoney_app.R`. |

## Dataset

The app expects `../data/pacific_federal_loan_campaign.csv` (relative to `TeamMoney_app.R`). Don't move it.

For development, there is a symlink at `app/data → ../data` (gitignored) so that `shiny::runApp("app/TeamMoney_app.R")` can find the dataset without needing the dataset to be duplicated.

## Run the app (dev server)

From the **repo root**:

```bash
Rscript -e 'shiny::runApp("app/TeamMoney_app.R", port = 7654, launch.browser = FALSE)'
```

Then open <http://127.0.0.1:7654>. Press `Ctrl+C` to stop. Drop `launch.browser = FALSE` to have it open your default browser automatically. Drop the port to let Shiny pick one.

In RStudio: open `TeamMoney_app.R` and click **Run App**.

## Render the report

```bash
quarto render app/TeamMoney_Mini_AI_Report.qmd --to html --embed-resources
```

The `--embed-resources` flag is required because the template's malformed YAML doesn't get the embed directive applied automatically; without it, the rendered HTML pulls in an external `_files/libs/` folder and the single-file submission breaks.

## Submission packaging

No copy step. Both submission files are already in this folder:

- `app/TeamMoney_app.R`
- `app/TeamMoney_Mini_AI_Report.html`

Upload these two directly to Canvas. Run the pre-flight check from `AI-plan.md` §11 step 4 first.

