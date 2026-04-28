# Mini AI Shiny App — Design Spec

**Project:** MGSC 310 Final Project — Mini AI Shiny App Prototype
**Team:** Team Money (Charlie, Arya, Steven, Ryan)
**Branch:** `feat/shiny-app`
**Date:** 2026-04-28
**Status:** Approved by Charlie; ready for plan-writing.

---

## 1. Goal

Build a Shiny app and rendered Quarto HTML report that lets a Pacific Federal marketing analyst compare two prospective loan-campaign customers ("Customer A" vs "Customer B") and see model-estimated probabilities of accepting a personal loan offer. The app must satisfy every line of the rubric (working app, data prep + model integration, outcome-connected viz, prediction tool + extra interactivity, README, AI Build Log, Reflection, overall thoughtfulness).

## 2. Submission artifacts

- `TeamMoney_app.R` — the Shiny app (copy of `app/app.R` produced at submission time, not during development).
- `TeamMoney_Mini_AI_Report.html` — rendered Quarto HTML (copy of `app/Mini_AI_Report.html` produced at submission time).
- The repo also keeps `app/app.R`, `app/Mini_AI_Report.qmd`, `app/Mini_AI_Report.html`, and this design doc.

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
│   ├── app.R                    # working Shiny app
│   ├── Mini_AI_Report.qmd       # working Quarto report (template YAML untouched)
│   ├── Mini_AI_Report.html      # rendered output (build artifact)
│   └── AI-plan.md               # this design doc
├── data/
│   └── pacific_federal_loan_campaign.csv
├── TeamMoney_app.R              # produced at submission only
└── TeamMoney_Mini_AI_Report.html # produced at submission only
```

The app loads data via `read.csv("data/pacific_federal_loan_campaign.csv", stringsAsFactors = TRUE)` — relative path, rubric-compliant. The grader can drop the dataset into `data/` and Run App without touching anything.

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
  title  = "Pacific Federal — Personal Loan Targeting Tool",
  theme  = bs_theme(version = 5, bootswatch = "flatly"),
  ...
)
```

### Tab 1 — "Explore the Data" (icon `bs_icon("graph-up")`)

`layout_columns(col_widths = c(4, 8))`:

- **Filters card (4/12).** `selectizeInput("edu_filter")` multi-select pre-checked to all three Education levels; `sliderInput("income_filter")` over the training-data Income range; small `helpText("Filters apply to the chart on the right.")`. *This is the rubric-mandated additional interactive element beyond the prediction button.*
- **Plot card (8/12).** `card_header` "Income vs predicted loan-acceptance probability"; `plotOutput("explore_plot", height = "520px")`; `card_footer` with a **static** caption: *"Higher-income customers, especially Graduate and Advanced/Professional segments, are far more likely to accept the loan offer. The dashed line marks the 0.5 decision threshold."* The caption does not change with filters — keeping it static avoids brittle string-rendering logic and is fine per the rubric (which only requires "a sentence telling the user what the plot shows and why it matters").

Plot specifics: ggplot, Income on x-axis, predicted probability on y-axis (computed by feeding the filtered subset through `predict(model, ..., type = "response")`), points colored by actual `Personal_Loan`, faceted by `Education`, dashed `geom_hline(yintercept = 0.5)`, `theme_minimal()`.

### Tab 2 — "Make a Prediction" (icon `bs_icon("calculator")`)

Four vertical zones:

**Zone 1 — Inputs.** `layout_columns(col_widths = c(6, 6))`:

- Customer A card. Header `span(bs_icon("person"), " Customer A")`. Six inputs in this order:
  - `numericInput("income_a", "Income (k$)", value = 40, min = 0, max = 300, step = 1)`
  - `selectInput("family_a", "Family size", choices = 1:4, selected = 2)`
  - `numericInput("ccavg_a", "Credit card avg / month (k$)", value = 1.0, min = 0, max = 10, step = 0.1)`
  - `selectInput("education_a", "Education", choices = levels(loans_train$Education), selected = "Undergrad")`
  - `selectInput("cd_account_a", "CD account?", choices = levels(loans_train$CD_Account), selected = "No")`
  - `numericInput("mortgage_a", "Mortgage (k$)", value = 0, min = 0, max = 700, step = 10)`
- Customer B card. Same layout with `_b` suffixed IDs and high-likelihood defaults: Income 180, Family 2, CCAvg 4.0, Education "Advanced/Professional", CD_Account "Yes", Mortgage 100.

The asymmetric defaults mean the demo on launch is immediately interesting without any typing.

**Zone 2 — Action + result row.** Centered `actionButton("predict_btn", "Compare Predictions", class = "btn-primary btn-lg")`. Then `layout_columns(col_widths = c(3, 3, 6))`:
- `value_box("Customer A — P(accept)", textOutput("prob_a"), showcase = bs_icon("person"), theme = "primary")`
- `value_box("Customer B — P(accept)", textOutput("prob_b"), showcase = bs_icon("person-fill"), theme = "success")`
- `card(card_header("Verdict"), textOutput("verdict"))` — sentence such as *"Customer B is **3.2× more likely** to accept the loan offer."*

Before the user has clicked the button: value boxes show "—" and the verdict card shows a friendly placeholder ("Click *Compare Predictions* to see results.").

**Zone 3 — Where they fall.** Full-width card. Header "Where Customer A and B fall in the data". Same plot type as Tab 1 (Income × predicted probability faceted by Education) but **not** filtered, with both customers added as `geom_point(shape = 8, size = 6)` stars + `geom_text` labels "A" and "B" placed at the customer's Income on the corresponding Education facet at their predicted probability. Below the plot, the **plain-English interpretation paragraph**:

> Each value above is the model's estimated probability that this specific customer would accept a personal-loan offer based on Income, Family size, monthly Credit Card spending (CCAvg), Education level, whether they hold a CD with the bank, and Mortgage. A higher probability does not mean the customer **will** accept — it means customers with similar profiles in the training data accepted at that rate. The bank should treat this as a relative ranking signal, not a guaranteed outcome.

**Zone 4 — Footnote.** Small muted div: *"Model: logistic regression. Trained on 80% of 5,000 customers. Test accuracy: XX.X% • Test AUC: 0.XX"* — populated from the startup-computed metrics.

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

1. The `selectInput` `choices` for these two inputs are sourced literally from `levels(loans_train$Education)` and `levels(loans_train$CD_Account)` — the user *cannot* select an out-of-vocab value.
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

1. **Static read.** Read `app.R` end-to-end for syntax, undefined symbols, dangling references.
2. **Headless launch.** Start the app via `Rscript -e 'shiny::runApp("app/app.R", port = 7654, launch.browser = FALSE)'` as a backgrounded Bash task. Confirm it binds to `127.0.0.1:7654` without stack traces in stderr.
3. **Playwright MCP browse.** Open `http://127.0.0.1:7654`, screenshot:
   1. Explore tab on launch (filters at default, plot rendered, caption visible).
   2. Predict tab on launch (defaults visible, value boxes show "—", placeholder verdict).
   3. Predict tab after clicking "Compare Predictions" (probabilities populated, plot has both stars + labels, verdict line visible).
   4. Move a filter on Explore tab → confirm plot re-renders.
   5. Change one Customer A input → re-click predict → confirm value box and verdict update.
4. **Factor sanity probe.** From an `Rscript` snippet, programmatically build the same `new_obs` the UI builds and call `predict()` to confirm no `contrasts can be applied only to factors with 2 or more levels` warning and no `factor X has new level` warning.
5. **Edge inputs.** Set Income to 0 and to 250; confirm graceful behavior (no NaN/Inf/NA shown to user).

## 11. Submission flow

1. Render `app/Mini_AI_Report.qmd` to HTML. **Open question:** the malformed YAML may cause Quarto to fail. If it does:
   - Try the minimum body fix to make Quarto happy *without touching the user-flagged YAML* (e.g., adjust heading indentation if Quarto chokes on it).
   - If that fails, ping Charlie with the actual Quarto error and let him decide whether to allow a YAML touch.
   - Document whichever path is taken in the AI Build Log.
2. Copy `app/app.R` → `TeamMoney_app.R` at repo root.
3. Copy `app/Mini_AI_Report.html` → `TeamMoney_Mini_AI_Report.html` at repo root.
4. Commit on `feat/shiny-app`. **Do not** merge to main — the team decides whether to take this branch.

## 12. Out of scope

- Deployment to shinyapps.io.
- Random forest or any non-logistic model.
- Cross-validation (rubric accepts plain train/test split).
- Caching the fitted model to disk.
- Internationalization, accessibility audit, mobile breakpoints (the prototype is desktop-only by intent).

## 13. AI Build Log composition (for the report, not the app)

Per Charlie's direction, the AI Build Log gets ≥2 substantive prompts plus ≥1 debug story, staged chronologically:

1. *"Use context7 to understand what shiny apps are."* — research kickoff.
2. *"What libraries do we need for a proper Shiny dashboard?"* — AI explained bslib + bsicons; team accepted.
3. *"Use subagents to build the model + the UI in parallel."* — parallel build.
4. *"There's something off with the YAML in the report template."* — AI caught the malformed Quarto YAML and recommended either a fix or document-and-leave; team chose document-and-leave.
5. *"Run /security-review on the final code."* — security review of inputs and data load.
6. ≥1 real debug story captured during implementation (e.g., factor-level mismatch, missing data path, plot not updating on filter change — whichever actually happens).

## 14. Open questions / risks

- **Quarto render risk** — see §11 step 1. We won't know until we try.
- **AUC by hand** — small risk of a numerical edge case if the test set has tied probabilities. Mitigation: standard pair-counting AUC, which handles ties correctly.
- **Plot performance** — 5000 points faceted by Education is fine; if the prediction overlay plot feels slow, drop to `geom_point(alpha = 0.3, size = 0.6)` and the stars stay visible.
