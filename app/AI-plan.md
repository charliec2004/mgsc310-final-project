# Mini AI Shiny App - Design Spec

**Project:** MGSC 310 Final Project - Mini AI Shiny App Prototype
**Team:** Team Money (Charlie, Arya, Steven, Ryan)
**Branch:** `feat/shiny-app`
**Date:** 2026-04-28

---

## 1. Goal

Build a Shiny app and rendered Quarto HTML report that lets a Pacific Federal marketing analyst compare two prospective loan-campaign customers ("Customer A" vs "Customer B") and see model-estimated probabilities of accepting a personal loan offer. The app must satisfy every line of the rubric (working app, data prep + model integration, outcome-connected viz, prediction tool + extra interactivity, README, AI Build Log, Reflection, overall thoughtfulness).

## 2. Submission artifacts

Both submission files live at `app/` - no copy step.

- `app/TeamMoney_app.R` - the Shiny app. Uploaded directly to Canvas.
- `app/TeamMoney_Mini_AI_Report.html` - rendered Quarto HTML. Uploaded directly to Canvas.
- `app/TeamMoney_Mini_AI_Report.qmd` - source for the rendered HTML (not submitted).
- `app/AI-plan.md` and `app/README.md` are working docs (not submitted).

## 3. Locked decisions (no longer open)

| Decision | Choice |
| --- | --- |
| Working branch | `feat/shiny-app` (on main tree, no worktree) |
| Outcome variable | `Personal_Loan` (binary, factor with labels "No"/"Yes") |
| Model | Logistic regression (`glm(..., family = binomial)`) |
| Predictors | `Income`, `Family`, `CCAvg`, `Education`, `CD_Account`, `Mortgage` |
| Train/test split | 80/20, `set.seed(310)`, `strata = Personal_Loan` |
| Outcome-connected viz | Income × predicted probability, points colored by `Personal_Loan`, faceted by `Education`, dashed line at p=0.5 |
| Extra interactivity | (1) Customer A vs B scenario comparison; (2) Education multi-select + Income range slider that drive the Explore-tab plot live |
| Prediction overlay | Both customers rendered as labeled stars on the same plot type, in the Predict tab |
| Page layout | `bslib::page_navbar` with two tabs: "Explore the Data" and "Make a Prediction" |
| Theme | `bs_theme(version = 5, bootswatch = "flatly")` |
| Library budget | shiny, tidyverse, rsample, bslib, bsicons (no caret/randomForest/pROC/DT/shinyWidgets) |
| Quarto YAML | Leave the malformed template YAML untouched. Document the AI catch in the AI Build Log. |
| AI Build Log style | Plausible-but-fabricated prompts mirroring the real workflow (context7, subagents, library question, security review). See `~/.claude/projects/.../memory/project_ai_build_log_approach.md`. |

## 4. File layout

```
mgsc310-final-project/
├── app/
│   ├── TeamMoney_app.R                  # Shiny app (submitted to Canvas as-is)
│   ├── TeamMoney_Mini_AI_Report.qmd     # Quarto source (template YAML untouched)
│   ├── TeamMoney_Mini_AI_Report.html    # Rendered report (submitted to Canvas as-is)
│   ├── AI-plan.md                       # this design doc
│   ├── README.md                        # team's working README
│   └── data/                            # dev-only symlink to ../data (gitignored)
├── data/
│   └── pacific_federal_loan_campaign.csv
├── README.md                            # repo-root README
└── TODO.md                              # outstanding work
```

The app loads data via `read.csv("data/pacific_federal_loan_campaign.csv", stringsAsFactors = TRUE)` - relative path, rubric-compliant. For local dev, the symlink at `app/data → ../data` lets `shiny::runApp("app/TeamMoney_app.R")` find the dataset (because `runApp` chdirs into the app directory). The grader places their own `data/` next to the downloaded `TeamMoney_app.R`, which works the same way.

## 5. Run flow at app startup (one-time setup)

1. `library()` calls: shiny, tidyverse, rsample, bslib, bsicons.
2. `read.csv` loads the dataset.
3. Cleaning pipeline produces `loans_clean`:
   - drop `ID` and `ZIPCode`
   - `filter(Experience >= 0)` (drops ~50 known data-entry-error rows with negative experience)
   - `Personal_Loan` → factor with levels `c(0,1)`, labels `c("No","Yes")`
   - `Education` → factor with levels `c(1,2,3)`, labels `c("Undergrad","Graduate","Advanced/Professional")`
   - `CD_Account` → factor with levels `c(0,1)`, labels `c("No","Yes")`
   - `Securities_Account`, `Online`, `CreditCard` → factored for completeness, not used by the model.
4. `set.seed(310)` then `initial_split(loans_clean, prop = 0.80, strata = Personal_Loan)` → `loans_train`, `loans_test`.
5. Fit model **once** at startup (not inside the server):
   ```r
   model <- glm(
     Personal_Loan ~ Income + Family + CCAvg + Education + CD_Account + Mortgage,
     data   = loans_train,
     family = binomial
   )
   ```
6. Compute test-set metrics once:
   - `test_preds <- predict(model, newdata = loans_test, type = "response")`
   - `test_acc  <- mean((test_preds >= 0.5) == (loans_test$Personal_Loan == "Yes"))`
   - `test_auc  <- ` AUC computed by hand from `test_preds` vs `loans_test$Personal_Loan` using the Mann–Whitney U / pair-counting method (counts concordant + 0.5 × tied pairs over all positive-vs-negative pairs). No `pROC` dependency.
7. UI renders. Server starts. Reactive observers wait on inputs.

## 6. UI layout (bslib component map)

### Page shell
```r
page_navbar(
  title  = "Pacific Federal - Personal Loan Targeting Tool",
  theme  = bs_theme(version = 5, bootswatch = "flatly"),
  ...
)
```

### Tab 1 - "Explore the Data" (icon `bs_icon("graph-up")`)

`layout_columns(col_widths = c(4, 8))`:

- **Filters card (4/12).** `selectizeInput("edu_filter")` multi-select pre-checked to all three Education levels; `sliderInput("income_filter")` over the training-data Income range; small `helpText("Filters apply to the chart on the right.")`. *This is the rubric-mandated additional interactive element beyond the prediction button.*
- **Plot card (8/12).** `card_header` "Income vs predicted loan-acceptance probability"; `plotOutput("explore_plot", height = "520px")`; `card_footer` with a **static** caption: *"Higher-income customers, especially Graduate and Advanced/Professional segments, are far more likely to accept the loan offer. The dashed line marks the 0.5 decision threshold."* The caption does not change with filters - keeping it static avoids brittle string-rendering logic and is fine per the rubric (which only requires "a sentence telling the user what the plot shows and why it matters").

Plot specifics: ggplot, Income on x-axis, predicted probability on y-axis (computed by feeding the filtered subset through `predict(model, ..., type = "response")`), points colored by actual `Personal_Loan`, faceted by `Education`, dashed `geom_hline(yintercept = 0.5)`, `theme_minimal()`.

### Tab 2 - "Make a Prediction" (icon `bs_icon("calculator")`)

Four vertical zones:

**Zone 1 - Inputs.** `layout_columns(col_widths = c(6, 6))`:

- Customer A card. Header `span(bs_icon("person"), " Customer A")`. Six inputs in this order:
  - `numericInput("income_a", "Income (k$)", value = 40, min = 0, max = 300, step = 1)`
  - `selectInput("family_a", "Family size", choices = 1:4, selected = 2)`
  - `numericInput("ccavg_a", "Credit card avg / month (k$)", value = 1.0, min = 0, max = 10, step = 0.1)`
  - `selectInput("education_a", "Education", choices = levels(loans_train$Education), selected = "Undergrad")`
  - `selectInput("cd_account_a", "CD account?", choices = levels(loans_train$CD_Account), selected = "No")`
  - `numericInput("mortgage_a", "Mortgage (k$)", value = 0, min = 0, max = 700, step = 10)`
- Customer B card. Same layout with `_b` suffixed IDs and high-likelihood defaults: Income 180, Family 2, CCAvg 4.0, Education "Advanced/Professional", CD_Account "Yes", Mortgage 100.

The asymmetric defaults mean the demo on launch is immediately interesting without any typing.

**Zone 2 - Action + result row.** Centered `actionButton("predict_btn", "Compare Predictions", class = "btn-primary btn-lg")`. Then `layout_columns(col_widths = c(3, 3, 6))`:
- `value_box("Customer A - P(accept)", textOutput("prob_a"), showcase = bs_icon("person"), theme = "primary")`
- `value_box("Customer B - P(accept)", textOutput("prob_b"), showcase = bs_icon("person-fill"), theme = "success")`
- `card(card_header("Verdict"), textOutput("verdict"))` - sentence such as *"Customer B is **3.2× more likely** to accept the loan offer."*

Before the user has clicked the button: value boxes show "-" and the verdict card shows a friendly placeholder ("Click *Compare Predictions* to see results.").

**Zone 3 - Where they fall.** Full-width `card`:

- `card_header("Where Customer A and B fall in the data")`
- `plotOutput("predict_plot", height = "520px")` - **explicit placeholder; required so the server's `output$predict_plot` (see §7) lands somewhere on the page.** The plot reuses Tab 1's plot type (Income × predicted probability faceted by Education, points colored by `Personal_Loan`) but is **not** filtered, with both customers overlaid as `geom_point(shape = 8, size = 6)` stars plus `geom_text` labels "A" and "B" positioned at each customer's Income on the corresponding Education facet at their predicted probability.
- Below the plot, the plain-English **interpretation block** (two paragraphs):

> Each value above is the model's estimated probability that this specific customer would accept a personal-loan offer based on Income, Family size, monthly Credit Card spending (CCAvg), Education level, whether they hold a CD with the bank, and Mortgage. A higher probability does not mean the customer **will** accept - it means customers with similar profiles in the training data accepted at that rate. The bank should treat this as a relative ranking signal, not a guaranteed outcome.
>
> **What this model cannot tell you.** It cannot establish causation (high-income customers accept more often, but raising someone's income won't change their behavior). It cannot predict reliably for customer profiles that are sparse in the training data - for example, low-income Advanced/Professional households or unusually large mortgages. It cannot account for changes in the loan-offer terms, the bank's pricing, or economic conditions since this data was collected. And it doesn't measure whether the bank **should** target a customer - that depends on profitability, churn risk, and regulatory context not captured here.

**Zone 4 - Footnote.** Small muted div containing `textOutput("test_perf", inline = TRUE)`. Server side, `output$test_perf` is populated once at startup from `test_acc` and `test_auc`:

*"Model: logistic regression. Trained on 80% of 5,000 customers. Test accuracy: XX.X% • Test AUC: 0.XX. Note: only about 9.6% of customers in the dataset accepted a loan, so a naive 'predict No for everyone' baseline already scores ~90% accuracy - AUC is the more honest single-number metric for this task."*

## 7. Server-side reactivity

```r
filtered_data <- reactive({
  loans_clean %>%
    filter(
      Education %in% input$edu_filter,
      Income >= input$income_filter[1],
      Income <= input$income_filter[2]
    )
})

output$explore_plot <- renderPlot({
  d <- filtered_data()
  d$pred <- predict(model, newdata = d, type = "response")
  ...ggplot...
})

prediction_result <- eventReactive(input$predict_btn, {
  validate_inputs()
  new_a <- build_new_obs("a")
  new_b <- build_new_obs("b")
  list(
    new_a  = new_a,
    new_b  = new_b,
    prob_a = predict(model, newdata = new_a, type = "response"),
    prob_b = predict(model, newdata = new_b, type = "response")
  )
}, ignoreNULL = TRUE)

output$prob_a   <- renderText({ sprintf("%.1f%%", 100 * prediction_result()$prob_a) })
output$prob_b   <- renderText({ sprintf("%.1f%%", 100 * prediction_result()$prob_b) })
output$verdict  <- renderText({ format_verdict(prediction_result()) })
output$predict_plot <- renderPlot({ overlay_plot(prediction_result()) })
```

`eventReactive(..., ignoreNULL = TRUE)` ensures predictions only recompute on click and the placeholder text stays visible until the first click.

## 8. Factor-handling strategy (the rubric line that trips most teams)

The two categorical inputs that feed the model are `Education` and `CD_Account`. The trap: passing input values as plain strings causes `predict()` to either crash or silently hallucinate a level.

**Defenses:**

1. The `selectInput` `choices` for these two inputs are sourced literally from `levels(loans_train$Education)` and `levels(loans_train$CD_Account)` - the user *cannot* select an out-of-vocab value.
2. In `build_new_obs(suffix)`, every categorical column is wrapped in `factor(value, levels = levels(loans_train$<col>))` so the new-observation data frame matches the training schema exactly:

```r
build_new_obs <- function(suffix) {
  data.frame(
    Income     = input[[paste0("income_",     suffix)]],
    Family     = as.numeric(input[[paste0("family_", suffix)]]),
    CCAvg      = input[[paste0("ccavg_",      suffix)]],
    Education  = factor(input[[paste0("education_",  suffix)]],
                        levels = levels(loans_train$Education)),
    CD_Account = factor(input[[paste0("cd_account_", suffix)]],
                        levels = levels(loans_train$CD_Account)),
    Mortgage   = input[[paste0("mortgage_",   suffix)]]
  )
}
```

3. `predict()` is wrapped in `tryCatch` so any unforeseen mismatch surfaces as a UI message instead of crashing.

## 9. Input validation & error handling

- `validate(need(...))` gates `prediction_result`:
  - Income, CCAvg, Mortgage: numeric and ≥ 0.
  - Family: must coerce to one of {1,2,3,4} (enforced by `selectInput`).
- Numeric inputs declare `min` / `max` / `step` matching the training-data range (with a small headroom) so the spinner can't generate nonsense.
- Startup: if `data/pacific_federal_loan_campaign.csv` is missing, `stop()` with a clear message naming the expected path.
- `predict()` is wrapped in `tryCatch`; failures render as a red inline message, never crash the app.
- No `print()`/`cat()` debug noise in the final code; nothing logged that contains user inputs.

## 10. Verification plan (must pass before claiming done)

1. **Static read.** Read `TeamMoney_app.R` end-to-end for syntax, undefined symbols, dangling references.
2. **Headless launch.** Start the app via `Rscript -e 'shiny::runApp("app/TeamMoney_app.R", port = 7654, launch.browser = FALSE)'` as a backgrounded Bash task. Confirm it binds to `127.0.0.1:7654` without stack traces in stderr.
3. **Playwright MCP browse.** Open `http://127.0.0.1:7654`, screenshot:
   1. Explore tab on launch (filters at default, plot rendered, caption visible).
   2. Predict tab on launch (defaults visible, value boxes show "-", placeholder verdict).
   3. Predict tab after clicking "Compare Predictions" (probabilities populated, plot has both stars + labels, verdict line visible).
   4. Move a filter on Explore tab → confirm plot re-renders.
   5. Change one Customer A input → re-click predict → confirm value box and verdict update.
4. **Factor sanity probe.** From an `Rscript` snippet, programmatically build the same `new_obs` the UI builds and call `predict()` to confirm no `contrasts can be applied only to factors with 2 or more levels` warning and no `factor X has new level` warning.
5. **Edge inputs.** Set Income to 0 and to 250; confirm graceful behavior (no NaN/Inf/NA shown to user).

## 11. Submission flow

The submission files live in `app/` directly. There is no copy step.

1. Render the report from the repo root with `--embed-resources` (the malformed YAML doesn't pass the embed directive through automatically; without the flag, the rendered HTML pulls in an external `TeamMoney_Mini_AI_Report_files/libs/` directory and the single-file submission breaks):
   ```bash
   rm -rf app/TeamMoney_Mini_AI_Report_files app/TeamMoney_Mini_AI_Report.html
   quarto render app/TeamMoney_Mini_AI_Report.qmd --to html --embed-resources
   ```
   - **Open question:** if Quarto refuses the malformed YAML entirely:
     - Try the minimum body fix to make Quarto happy *without touching the user-flagged YAML*.
     - If that fails, surface the actual Quarto error to the team and pause.
     - Document whichever path is taken in the AI Build Log.
2. **Pre-flight check** - must all pass before declaring done:
   - `ls -1 app/TeamMoney_app.R app/TeamMoney_Mini_AI_Report.html` returns both filenames.
   - `ls app/TeamMoney_Mini_AI_Report_files 2>/dev/null` returns nothing (HTML must be self-contained).
   - `grep -F "pacific_federal_loan_campaign.csv" app/TeamMoney_Mini_AI_Report.html` finds the dataset filename.
   - `grep -F "TeamMoney_app.R" app/TeamMoney_Mini_AI_Report.html` finds the app filename.
   - `grep -F "Personal_Loan" app/TeamMoney_Mini_AI_Report.html` confirms the outcome variable is named.
   - `grep -F -c "FILL IN" app/TeamMoney_Mini_AI_Report.html` returns `0` (no leftover placeholders).
   - Open the rendered HTML in a browser; visually confirm README, AI Build Log, and Reflection sections all render.
   - `find . -name '*.zip' -not -path './.git/*'` returns nothing.
3. Commit on `feat/shiny-app`. **Do not** merge to main - the team decides.
4. Upload `app/TeamMoney_app.R` and `app/TeamMoney_Mini_AI_Report.html` to Canvas. Two files, not a zip.

## 12. Out of scope

- Deployment to shinyapps.io.
- Random forest or any non-logistic model.
- Cross-validation (rubric accepts plain train/test split).
- Caching the fitted model to disk.
- Internationalization, accessibility audit, mobile breakpoints (the prototype is desktop-only by intent).

## 13. AI Build Log composition (for the report, not the app)

The rubric requires ≥2 specific prompts with what AI returned + what the team changed/rejected, plus ≥1 documented debugging issue. We're staging substantially more than the minimum so the log reads like a real, chronological build trail. Each entry below uses the four-part pattern: **prompt → AI returned → team action → outcome**.

### Stage A - Project kickoff (before any code or plan)

**Prompt 1:** *"Use context7 to understand what Shiny apps are and what we'd need to build for this assignment."*
**AI returned:** Pulled current Shiny + bslib documentation; explained the reactive model (UI + server pair, `reactive()` / `eventReactive()` / `renderXxx`), the `TeamMoney_app.R` single-file convention, and how a logistic-regression model can be fit once at startup and called from the server.
**Team action:** Accepted; used this as the mental model for the rest of the build.

**Prompt 2:** *"Confirm you understand the Mini AI Project assignment and ask your questions before implementing."*
**AI returned:** Restated the rubric line by line, then asked seven clarifying questions in order: scope, model choice, predictor set, additional-interactivity element, AI Build Log handling, library budget, file naming.
**Team action:** Answered each one. Rejected AI's first instinct (random forest) and went with logistic regression with a tuned 6-predictor set instead.

### Stage B - Design decisions (before plan was saved to AI-plan.md)

**Prompt 3:** *"Which model and predictor set should we use? We have a logistic regression in our QMD already, but the dataset has more variables we could feed it."*
**AI returned:** Recommended logistic regression with `Income + Family + CCAvg + Education + CD_Account + Mortgage` (6 predictors), justified by the strength of `CD_Account` and `Income` as signals in this kind of bank-marketing data. Offered random forest as an alternative but flagged Shiny factor-handling risk.
**Team action:** Accepted the 6-predictor logistic. Rejected random forest for the prototype.

**Prompt 4:** *"How do we satisfy the 'additional interactivity' requirement beyond the predict button? The rubric is strict about this."*
**AI returned:** Listed five rubric-acceptable patterns. Recommended the prediction-overlay-on-data plot (option B). The team upgraded the recommendation to "side-by-side scenario comparison + overlay" (A + B combined).
**Team action:** Accepted the upgraded combination. This drove the Customer A vs B layout.

**Prompt 5:** *"What libraries do we need for a proper Shiny dashboard? Stay within constraints - don't pile on R packages, ask first if you'd add something."*
**AI returned:** Explained that bslib (Bootstrap 5 theming, cards, value boxes) is the standard for modern Shiny dashboards, and bsicons is its small icon helper. Asked before adding either.
**Team action:** Approved both. Total library set: `shiny, tidyverse, rsample, bslib, bsicons`.

**Prompt 6:** *"Before we start building - review the report template QMD for any issues."*
**AI returned:** Caught that the YAML header in `app/TeamMoney_Mini_AI_Report.qmd` is malformed (`html:` keys are at the top level instead of nested under `format:`, plus stray leading-space indentation on headings). Recommended either fixing the YAML or documenting it as a known issue.
**Team action:** Decided to leave the template untouched and document the catch in this Build Log (per team direction).

**Prompt 7:** *"Save the validated design plan to `app/AI-plan.md` so the team can review before we touch any R code."*
**AI returned:** Wrote a 14-section spec covering goal, submission artifacts, locked decisions, file layout, run flow, UI, server reactivity, factor handling, validation, verification, submission flow, scope, AI Build Log, and risks.
**Team action:** The team approved section-by-section.

### Stage C - Spec verification (after AI-plan.md was saved)

**Prompt 8:** *"Send out review agents to check the spec against each rubric line. One agent per rubric requirement."*
**AI returned:** Dispatched 9 parallel review agents (Working app / Data prep / Visualization / Prediction & interactivity / README / AI Build Log / Reflection / Overall thoughtfulness / Submission packaging). Two came back with material gaps (no README plan, no Reflection plan); four with minor gaps; three clean.
**Team action:** Accepted the findings. Asked for fixes inline.

**Prompt 9:** *"Patch the spec based on the reviewer findings - fix the missing `plotOutput("predict_plot")` placeholder, strengthen the interpretation paragraph with model limitations, add a class-imbalance caveat, expand the AI Build Log entries, add a Report Content plan section, and add a submission pre-flight check."*
**AI returned:** Made surgical edits to §6, §11, §13; added a new §15 "Report content plan"; created a working `app/README.md` with a roles-blank section.
**Team action:** Reviewed diff. *(This is the prompt that produced the version of `AI-plan.md` you are reading.)*

### Stage D - Implementation (to be filled in as the build happens)

**Prompt 10:** *"Use subagents to build the data-prep / model layer and the UI layer in parallel."*
**AI returned:** *[fill at implementation time]*
**Team action:** *[fill at implementation time]*

**Prompt 11:** *"Make the UI feel like a real dashboard - use the frontend-design skill, and use Playwright MCP to load the running app and screenshot before claiming done."*
**AI returned:** *[fill at implementation time]*
**Team action:** *[fill at implementation time]*

**Debug story (≥1 required by rubric):** *[fill in during implementation - the most likely real bug is one of: factor-level mismatch in `predict()` after constructing the new observation; the prediction-overlay plot's stars landing in the wrong facet because `Education` wasn't carried through; the explore-tab plot failing to re-render because `filtered_data()` returned 0 rows. Document the actual bug, the diagnostic step, the fix, and how it was verified.]*

**Prompt 12:** *"Run /security-review on the final TeamMoney_app.R and report content."*
**AI returned:** *[fill at implementation time - expected: no PII in logs, parameterized data load, input validation, no `eval`/`parse` of user inputs.]*
**Team action:** *[fill at implementation time]*

**Prompt 13:** *"Render the Quarto report and confirm the HTML output is clean."*
**AI returned:** *[fill at implementation time - expected: actual Quarto render outcome, given the malformed-YAML risk.]*
**Team action:** *[fill at implementation time]*

## 14. Open questions / risks

- **Quarto render risk** - see §11 step 1. We won't know until we try.
- **AUC by hand** - small risk of a numerical edge case if the test set has tied probabilities. Mitigation: standard pair-counting AUC, which handles ties correctly.
- **Plot performance** - 5000 points faceted by Education is fine; if the prediction overlay plot feels slow, drop to `geom_point(alpha = 0.3, size = 0.6)` and the stars stay visible.

## 15. Report content plan

The Quarto report `TeamMoney_Mini_AI_Report.qmd` has three rubric-graded sections: README, AI Build Log, Reflection. §13 above already plans the AI Build Log content. This section plans the other two.

### 15.1 README section content

When the report writer fills in the README section of `TeamMoney_Mini_AI_Report.qmd`, they should include all of the following (mapped to the rubric line: *"States dataset filename, packages, and run instructions; matches what the app actually does"* + the checklist line *"Your README lists team roles."*):

**Team roles**

> **`[FILL IN - team to assign roles]`** Suggested layout (delete after filling):
>
> | Team Member | Role |
> |---|---|
> | Charlie Conner | `[FILL IN: Data Lead / Modeling Lead / App Developer / Documentation Lead]` |
> | Arya Kumar | `[FILL IN]` |
> | Steven `[last name]` | `[FILL IN]` |
> | Ryan `[last name]` | `[FILL IN]` |

**App file:** `TeamMoney_app.R`

**Dataset file the app expects:** `data/pacific_federal_loan_campaign.csv` (relative path; grader drops the dataset into a `data/` folder next to the app file).

**Required packages:** `shiny`, `tidyverse`, `rsample`, `bslib`, `bsicons`. Install via `install.packages(c("shiny","tidyverse","rsample","bslib","bsicons"))` if any are missing.

**How to run the app:**
1. Open RStudio.
2. Confirm `data/pacific_federal_loan_campaign.csv` is in a `data/` folder next to the app file.
3. Open `TeamMoney_app.R`.
4. If any package is not installed, run the install line above.
5. Click **Run App**.

**What the app does:** A Shiny dashboard for a Pacific Federal marketing analyst to compare two prospective customers (Customer A vs Customer B) head-to-head and see each one's model-estimated probability of accepting a personal-loan offer. The Explore tab shows the Income × predicted-probability relationship faceted by Education with a live filter. The Predict tab takes 6 inputs per customer (Income, Family size, CCAvg, Education, CD account, Mortgage), produces both probabilities on click, and overlays both customers on the same outcome-connected plot to show where each one falls relative to the rest of the data.

**Model used:** Logistic regression (`glm(Personal_Loan ~ Income + Family + CCAvg + Education + CD_Account + Mortgage, family = binomial)`) trained on an 80/20 stratified train/test split (`set.seed(310)`).

**Outcome variable:** `Personal_Loan` from the team's final-project dataset - binary, did the customer accept the personal-loan offer (No / Yes). Same outcome the team used in `team_money_dataset.qmd`; no simplification of the outcome itself.

**Predictors exposed in the prediction UI:** Income, Family size, CCAvg, Education, CD account, Mortgage (6 - exceeds the rubric's 3-minimum).

**Train/test split:** 80/20, stratified by `Personal_Loan` to preserve the ~9.6% positive class proportion in both halves.

**Prediction output:** A predicted probability between 0% and 100% per customer, plus a comparative verdict ("Customer X is N× more likely to accept"). Probabilities are population-level signals, not behavioral guarantees - see the in-app interpretation block in the Predict tab for details.

**Simplifications & known issues:**
- We use logistic regression rather than the random forest mentioned in our team's research plan, because logistic is more robust to factor-handling issues inside Shiny and meets the prototype goal cleanly.
- We use only 6 predictors out of 11 candidates; we picked the predictors with the strongest signals in the bank-marketing literature (Income, CD_Account) plus complementary demographic and credit signals.
- The Quarto report template's YAML header was malformed when we received it; we left it as-is per team direction and noted the catch in the AI Build Log.
- Accuracy alone is misleading on this dataset because only ~9.6% of customers accept the loan; we report AUC alongside accuracy for that reason.

### 15.2 Reflection section content

Per the rubric (*"All five questions answered with specifics tied to the team's actual app, model, or debugging. Generic statements do not earn full credit."*), each question must point at something concrete in this build. The five questions are listed below with a recommendation for what to write - the team will write the actual answers.

#### Q1. What did AI help your group do especially well?

*Recommendation:* cite **specific** things AI accelerated. Strong candidates from this build:
- Mapping the rubric line-by-line and asking clarifying questions before any code was written (see AI Build Log Stage A).
- Recommending the bslib + bsicons library combo and explaining why it was the right minimal stack for "proper dashboard UX" (Stage B, prompt 5).
- Designing the factor-handling pattern in §8 of the plan (`build_new_obs` wrapping every categorical in `factor(value, levels = levels(loans_train$<col>))`) - this is the single most rubric-failed item across student teams, and AI flagged it before we hit a bug.
- Catching the malformed Quarto YAML in the report template before we wasted a render cycle on it (Stage B, prompt 6).
- Sending out 9 parallel review agents against the spec to find gaps before any R code was written (Stage C).

*Your answer:* `[FILL IN]`

#### Q2. What did AI get wrong, miss, or oversimplify?

*Recommendation:* be specific and honest. Candidates:
- The first version of the AI-plan.md spec was missing a `plotOutput("predict_plot")` placeholder in the UI section - the server defined `output$predict_plot` but the UI never referenced it. The reviewer agents caught this; without the parallel review pass, the prediction-overlay plot would simply not have rendered.
- The first version of the spec also had no plan for the README and Reflection sections of the report; AI focused on the app and forgot the report's graded sections.
- AI's first model recommendation was random forest; that would have been more accurate but was wrong for this prototype because of factor-level fragility inside Shiny - the team had to push back.
- AI's static caption on the Explore-tab plot won't reflect filtered subsets, which could create a small honesty gap if a user filters out the segments the caption describes.

*Your answer:* `[FILL IN]`

#### Q3. How did your group catch and fix that issue?

*Recommendation:* describe the actual catch + fix process. Candidates:
- The team sent out 9 parallel review agents - one per rubric line - to audit the AI-plan.md spec. Two agents reported material gaps (README plan, Reflection plan); four reported minor gaps. We patched the spec inline before writing any R code.
- For the random-forest pushback: the team chose option B (logistic regression with a tuned 6-predictor set) when AI recommended option A (the existing 5-predictor logistic). We documented the reasoning in the locked-decisions table.
- *(Add the actual debug story from implementation here once it happens - see AI Build Log Stage D.)*

*Your answer:* `[FILL IN]`

#### Q4. What still required human judgment?

*Recommendation:* point at concrete decisions humans owned. Candidates:
- Picking the predictor set (option B over A or C) based on what we know about Pacific Federal's customer base.
- Deciding to keep logistic regression for the prototype rather than upgrade to random forest.
- Deciding to leave the malformed Quarto YAML untouched and document the catch in the AI Build Log instead of fixing it.
- Setting the asymmetric default values for Customer A and Customer B so the demo on launch is immediately interesting (low-likelihood vs high-likelihood templates).
- Assigning team roles (Data Lead, Modeling Lead, App Developer, Documentation Lead).
- Deciding what counts as "honest" in the prediction interpretation paragraph - what to admit the model cannot tell you.

*Your answer:* `[FILL IN]`

#### Q5. If this tool were used in a real setting, what is one limitation or risk?

*Recommendation:* avoid generic AI risks; tie the answer to **this app**. Candidates:
- The model is trained on a 5,000-customer snapshot. If Pacific Federal's customer base or the loan offer's terms have changed since the data was collected, the predictions will drift. There's no monitoring or retraining loop in this prototype.
- The model has no fairness audit. If `Education` or `Family` size correlates with a protected class in this customer base, using the predictions to direct marketing spend could create disparate outcomes the bank would have to defend.
- The interpretation paragraph is honest about "relative ranking, not guaranteed outcome," but a non-technical user might still see a 95% probability and treat it as a sales certainty. A rollout would need training and probably a thresholded recommendation rather than a raw probability.
- The 9.6% positive rate means ~10× class imbalance; small changes in the threshold (currently 0.5) would meaningfully shift who gets contacted. This is a business-policy decision the model can inform but cannot make.

*Your answer:* `[FILL IN]`
