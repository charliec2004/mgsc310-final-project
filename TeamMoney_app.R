# ---------------------------------------------------------
# Pacific Federal - Personal Loan Targeting Tool
# Team Money: Charlie Conner, Arya Kumar, Steven, Ryan
# MGSC 310 Final Project - Mini AI Shiny App Prototype
# ---------------------------------------------------------

library(shiny)
library(tidyverse)
library(rsample)
library(bslib)
library(bsicons)

# ---------------------------------------------------------
# 1. Load + clean data
# ---------------------------------------------------------

DATA_PATH <- "data/pacific_federal_loan_campaign.csv"

if (!file.exists(DATA_PATH)) {
  stop(sprintf(
    "Could not find dataset at '%s'. Place the CSV in a 'data' folder next to app.R.",
    DATA_PATH
  ))
}

loans_raw <- read.csv(DATA_PATH, stringsAsFactors = FALSE)

loans_clean <- loans_raw %>%
  filter(Experience >= 0) %>%
  select(-ID, -ZIPCode) %>%
  mutate(
    Personal_Loan      = factor(Personal_Loan, levels = c(0, 1), labels = c("No", "Yes")),
    Education          = factor(Education,     levels = c(1, 2, 3),
                                labels = c("Undergrad", "Graduate", "Advanced/Professional")),
    CD_Account         = factor(CD_Account,    levels = c(0, 1), labels = c("No", "Yes")),
    Securities_Account = factor(Securities_Account, levels = c(0, 1), labels = c("No", "Yes")),
    Online             = factor(Online,        levels = c(0, 1), labels = c("No", "Yes")),
    CreditCard         = factor(CreditCard,    levels = c(0, 1), labels = c("No", "Yes"))
  )

# ---------------------------------------------------------
# 2. Train/test split
# ---------------------------------------------------------

set.seed(310)
loans_split <- initial_split(loans_clean, prop = 0.80, strata = Personal_Loan)
loans_train <- training(loans_split)
loans_test  <- testing(loans_split)

# ---------------------------------------------------------
# 3. Model fit (logistic regression)
# ---------------------------------------------------------

model <- glm(
  Personal_Loan ~ Income + Family + CCAvg + Education + CD_Account + Mortgage,
  data   = loans_train,
  family = binomial
)

# ---------------------------------------------------------
# 4. Test-set performance (computed once, displayed in app)
# ---------------------------------------------------------

compute_auc <- function(scores, labels_pos) {
  pos <- scores[labels_pos]
  neg <- scores[!labels_pos]
  if (length(pos) == 0 || length(neg) == 0) return(NA_real_)
  pair_count <- length(pos) * length(neg)
  concordant <- sum(outer(pos, neg, ">"))
  ties       <- sum(outer(pos, neg, "=="))
  (concordant + 0.5 * ties) / pair_count
}

test_preds <- predict(model, newdata = loans_test, type = "response")
test_labels_pos <- loans_test$Personal_Loan == "Yes"
test_acc <- mean((test_preds >= 0.5) == test_labels_pos)
test_auc <- compute_auc(test_preds, test_labels_pos)

POSITIVE_RATE <- mean(loans_clean$Personal_Loan == "Yes")
test_perf_text <- sprintf(
  paste0(
    "Model: logistic regression. Trained on 80%% of %d customers. ",
    "Test accuracy: %.1f%% • Test AUC: %.2f. ",
    "Note: only ~%.1f%% of customers in the dataset accepted a loan, so a naive ",
    "'predict No for everyone' baseline already scores ~%.0f%% accuracy - ",
    "AUC is the more honest single-number metric for this task."
  ),
  nrow(loans_clean),
  100 * test_acc,
  test_auc,
  100 * POSITIVE_RATE,
  100 * (1 - POSITIVE_RATE)
)

# ---------------------------------------------------------
# 5. Helper functions used by the server
# ---------------------------------------------------------

build_new_obs <- function(input, suffix) {
  data.frame(
    Income     = as.numeric(input[[paste0("income_",     suffix)]]),
    Family     = as.numeric(input[[paste0("family_",     suffix)]]),
    CCAvg      = as.numeric(input[[paste0("ccavg_",      suffix)]]),
    Education  = factor(input[[paste0("education_",  suffix)]],
                        levels = levels(loans_train$Education)),
    CD_Account = factor(input[[paste0("cd_account_", suffix)]],
                        levels = levels(loans_train$CD_Account)),
    Mortgage   = as.numeric(input[[paste0("mortgage_",   suffix)]])
  )
}

safe_name <- function(x, fallback) {
  x <- if (is.null(x)) "" else trimws(as.character(x))
  if (!nzchar(x)) fallback else x
}

format_verdict <- function(prob_a, prob_b, name_a = "Customer A", name_b = "Customer B") {
  if (is.na(prob_a) || is.na(prob_b)) {
    return("Click Compare Predictions to see results.")
  }
  diff_pp <- abs(prob_a - prob_b) * 100
  if (diff_pp < 1) {
    return(sprintf(
      "%s (%.1f%%) and %s (%.1f%%) have nearly identical estimated probabilities of accepting the loan offer.",
      name_a, 100 * prob_a, name_b, 100 * prob_b
    ))
  }
  if (prob_a > prob_b) {
    bigger_name <- name_a; smaller_name <- name_b; bp <- prob_a; sp <- prob_b
  } else {
    bigger_name <- name_b; smaller_name <- name_a; bp <- prob_b; sp <- prob_a
  }
  ratio <- if (sp > 0.005) bp / sp else NA_real_
  if (is.na(ratio) || ratio > 100) {
    sprintf(
      "%s (%.1f%%) is far more likely to accept the loan offer than %s (%.1f%%).",
      bigger_name, 100 * bp, smaller_name, 100 * sp
    )
  } else {
    sprintf(
      "%s (%.1f%%) is %.1fx more likely to accept the loan offer than %s (%.1f%%).",
      bigger_name, 100 * bp, ratio, smaller_name, 100 * sp
    )
  }
}

build_explore_plot <- function(plot_data) {
  if (nrow(plot_data) == 0) {
    return(
      ggplot() +
        annotate("text", x = 0, y = 0,
                 label = "No customers match the current filters.\nWiden the Income range or add an Education level.",
                 size = 5, color = "#555") +
        theme_void()
    )
  }
  plot_data$pred <- predict(model, newdata = plot_data, type = "response")
  ggplot(plot_data, aes(x = Income, y = pred, color = Personal_Loan)) +
    geom_point(alpha = 0.45, size = 1.4) +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = "#888") +
    facet_wrap(~ Education) +
    scale_color_manual(values = c("No" = "#7a8898", "Yes" = "#2c7be5")) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
    labs(
      x = "Annual income (thousand $)",
      y = "Predicted probability of accepting loan",
      color = "Actually accepted?"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold"),
      legend.position = "top"
    )
}

truncate_name <- function(x, n = 14) {
  x <- as.character(x)
  ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "…"), x)
}

build_predict_plot <- function(prediction_result) {
  base <- build_explore_plot(loans_clean)
  if (is.null(prediction_result)) return(base)
  overlay_df <- data.frame(
    Income        = c(prediction_result$new_a$Income,    prediction_result$new_b$Income),
    pred          = c(prediction_result$prob_a,           prediction_result$prob_b),
    Education     = c(prediction_result$new_a$Education,  prediction_result$new_b$Education),
    label         = truncate_name(c(prediction_result$name_a, prediction_result$name_b)),
    Personal_Loan = factor(c("Yes", "Yes"), levels = levels(loans_clean$Personal_Loan))
  )
  base +
    geom_point(data = overlay_df,
               aes(x = Income, y = pred),
               shape = 8, size = 7, color = "#e63946", stroke = 1.4,
               inherit.aes = FALSE) +
    geom_label(data = overlay_df,
               aes(x = Income, y = pred, label = label),
               nudge_y = 0.07, size = 4.4, fontface = "bold",
               color = "#e63946", fill = "white", label.size = 0.6,
               inherit.aes = FALSE)
}

# ---------------------------------------------------------
# 6. UI
# ---------------------------------------------------------

INCOME_RANGE   <- range(loans_train$Income)
MORTGAGE_RANGE <- c(0, max(loans_train$Mortgage) + 50)

ui <- page_navbar(
  title    = "Pacific Federal - Personal Loan Targeting Tool",
  theme    = bs_theme(version = 5, bootswatch = "flatly"),
  bg       = "#1f3b57",
  fillable = FALSE,

  header = tags$head(tags$style(HTML("
    /* Navbar tabs: keep both active and inactive tabs white-on-navy. */
    .navbar .nav-link,
    .navbar .navbar-nav .nav-link {
      color: rgba(255, 255, 255, 0.85) !important;
      padding-left: 1.4rem !important;
      padding-right: 1.4rem !important;
      padding-top: 0.55rem !important;
      padding-bottom: 0.55rem !important;
    }
    .navbar .navbar-nav .nav-item + .nav-item {
      margin-left: 0.4rem;
    }
    .navbar .nav-link:hover,
    .navbar .navbar-nav .nav-link:hover {
      color: #ffffff !important;
      background-color: rgba(255, 255, 255, 0.10) !important;
      border-radius: 4px;
    }
    .navbar .nav-link.active,
    .navbar .navbar-nav .nav-link.active {
      color: #ffffff !important;
      background-color: rgba(255, 255, 255, 0.06) !important;
      border-radius: 4px;
    }
    /* Underline accent for nav-underline-style navbars (bslib default). */
    .navbar .nav-underline .nav-link.active {
      border-bottom-color: #ffffff !important;
    }
  "))),


  nav_panel(
    title = "Explore the Data",
    icon  = bs_icon("graph-up"),

    layout_columns(
      col_widths = c(4, 8),

      card(
        card_header(span(bs_icon("funnel"), " Filters")),
        card_body(
          tags$p(
            class = "text-muted small mb-3",
            "Use these controls to narrow which customers appear in the chart on the right. ",
            "Both filters update the chart immediately."
          ),
          selectizeInput(
            "edu_filter",
            label    = "Education levels to include (click below to remove or add)",
            choices  = levels(loans_train$Education),
            selected = levels(loans_train$Education),
            multiple = TRUE,
            options  = list(
              plugins     = list("remove_button"),
              placeholder = "Click to add an Education level..."
            )
          ),
          tags$p(
            class = "text-muted small mb-3",
            "Choices: Undergrad, Graduate, Advanced/Professional. ",
            "All three are selected by default - remove any with the × button."
          ),
          sliderInput(
            "income_filter",
            label = "Income range (thousand $) - drag the handles",
            min   = floor(INCOME_RANGE[1]),
            max   = ceiling(INCOME_RANGE[2]),
            value = c(floor(INCOME_RANGE[1]), ceiling(INCOME_RANGE[2])),
            step  = 1
          ),
          tags$p(
            class = "text-muted small",
            sprintf(
              "Training data spans $%dk to $%dk in annual income.",
              floor(INCOME_RANGE[1]), ceiling(INCOME_RANGE[2])
            )
          )
        )
      ),

      card(
        card_header("Income vs. predicted loan-acceptance probability"),
        plotOutput("explore_plot", height = "520px"),
        card_footer(
          tags$em(
            "Higher-income customers, especially in the Graduate and Advanced/Professional ",
            "segments, are far more likely to accept the loan offer. The dashed line marks ",
            "the 0.5 decision threshold."
          )
        )
      )
    )
  ),

  nav_panel(
    title = "Make a Prediction",
    icon  = bs_icon("calculator"),

    layout_columns(
      col_widths = c(6, 6),
      fillable   = FALSE,

      card(
        fill = FALSE,
        card_header(span(bs_icon("person"), " Customer A")),
        card_body(
          fillable = FALSE,
          textInput   ("name_a",       "Name (label only - not used by the model)", value = "Customer A", placeholder = "e.g. Sarah K."),
          numericInput("income_a",     "Income (thousand $)",          value = 40,  min = 0, max = 300, step = 1),
          selectInput ("family_a",     "Family size",                  choices = 1:4, selected = 2),
          numericInput("ccavg_a",      "Credit card avg / month (k$)", value = 1.0, min = 0, max = 10,  step = 0.1),
          selectInput ("education_a",  "Education",                    choices = levels(loans_train$Education),  selected = "Undergrad"),
          selectInput ("cd_account_a", "CD account?",                  choices = levels(loans_train$CD_Account), selected = "No"),
          numericInput("mortgage_a",   "Mortgage (thousand $)",        value = 0,   min = 0, max = MORTGAGE_RANGE[2], step = 10)
        )
      ),

      card(
        fill = FALSE,
        card_header(span(bs_icon("person-fill"), " Customer B")),
        card_body(
          fillable = FALSE,
          textInput   ("name_b",       "Name (label only - not used by the model)", value = "Customer B", placeholder = "e.g. Marcus T."),
          numericInput("income_b",     "Income (thousand $)",          value = 180, min = 0, max = 300, step = 1),
          selectInput ("family_b",     "Family size",                  choices = 1:4, selected = 2),
          numericInput("ccavg_b",      "Credit card avg / month (k$)", value = 4.0, min = 0, max = 10,  step = 0.1),
          selectInput ("education_b",  "Education",                    choices = levels(loans_train$Education),  selected = "Advanced/Professional"),
          selectInput ("cd_account_b", "CD account?",                  choices = levels(loans_train$CD_Account), selected = "Yes"),
          numericInput("mortgage_b",   "Mortgage (thousand $)",        value = 100, min = 0, max = MORTGAGE_RANGE[2], step = 10)
        )
      )
    ),

    div(
      class = "d-flex justify-content-center my-3",
      actionButton("predict_btn", "Compare Predictions",
                   class = "btn-primary btn-lg",
                   icon  = bs_icon("play-fill"))
    ),

    layout_columns(
      col_widths = c(3, 3, 6),
      value_box(
        title    = textOutput("title_a"),
        value    = textOutput("prob_a"),
        showcase = bs_icon("person"),
        theme    = "primary"
      ),
      value_box(
        title    = textOutput("title_b"),
        value    = textOutput("prob_b"),
        showcase = bs_icon("person-fill"),
        theme    = "success"
      ),
      card(
        card_header("Verdict"),
        card_body(textOutput("verdict"))
      )
    ),

    card(
      card_header("Where Customer A and B fall in the data"),
      plotOutput("predict_plot", height = "520px"),
      card_body(
        tags$p(
          "Each value above is the model's estimated probability that this specific customer ",
          "would accept a personal-loan offer based on Income, Family size, monthly Credit Card ",
          "spending (CCAvg), Education level, whether they hold a CD with the bank, and Mortgage. ",
          "A higher probability does not mean the customer ", tags$strong("will"),
          " accept - it means customers with similar profiles in the training data accepted ",
          "at that rate. The bank should treat this as a relative ranking signal, not a ",
          "guaranteed outcome."
        ),
        tags$p(
          tags$strong("What this model cannot tell you. "),
          "It cannot establish causation (high-income customers accept more often, but raising ",
          "someone's income won't change their behavior). It cannot predict reliably for ",
          "customer profiles that are sparse in the training data - for example, low-income ",
          "Advanced/Professional households or unusually large mortgages. It cannot account for ",
          "changes in the loan-offer terms, the bank's pricing, or economic conditions since ",
          "this data was collected. And it doesn't measure whether the bank ", tags$em("should"),
          " target a customer - that depends on profitability, churn risk, and regulatory ",
          "context not captured here."
        )
      )
    ),

    div(
      class = "text-muted small mt-2",
      textOutput("test_perf", inline = TRUE)
    )
  )
)

# ---------------------------------------------------------
# 7. Server
# ---------------------------------------------------------

server <- function(input, output, session) {

  filtered_data <- reactive({
    req(input$edu_filter, input$income_filter)
    loans_clean %>%
      filter(
        Education %in% input$edu_filter,
        Income    >= input$income_filter[1],
        Income    <= input$income_filter[2]
      )
  })

  output$explore_plot <- renderPlot({
    build_explore_plot(filtered_data())
  })

  output$title_a <- renderText({
    paste0(safe_name(input$name_a, "Customer A"), " - P(accept)")
  })
  output$title_b <- renderText({
    paste0(safe_name(input$name_b, "Customer B"), " - P(accept)")
  })

  prediction_result <- eventReactive(input$predict_btn, {
    validate(
      need(is.numeric(input$income_a)   && input$income_a   >= 0, "Customer A: Income must be ≥ 0."),
      need(is.numeric(input$income_b)   && input$income_b   >= 0, "Customer B: Income must be ≥ 0."),
      need(is.numeric(input$ccavg_a)    && input$ccavg_a    >= 0, "Customer A: CCAvg must be ≥ 0."),
      need(is.numeric(input$ccavg_b)    && input$ccavg_b    >= 0, "Customer B: CCAvg must be ≥ 0."),
      need(is.numeric(input$mortgage_a) && input$mortgage_a >= 0, "Customer A: Mortgage must be ≥ 0."),
      need(is.numeric(input$mortgage_b) && input$mortgage_b >= 0, "Customer B: Mortgage must be ≥ 0.")
    )
    new_a <- build_new_obs(input, "a")
    new_b <- build_new_obs(input, "b")
    prob_a <- tryCatch(
      as.numeric(predict(model, newdata = new_a, type = "response")),
      error = function(e) NA_real_
    )
    prob_b <- tryCatch(
      as.numeric(predict(model, newdata = new_b, type = "response")),
      error = function(e) NA_real_
    )
    list(
      name_a = safe_name(input$name_a, "Customer A"),
      name_b = safe_name(input$name_b, "Customer B"),
      new_a  = new_a,
      new_b  = new_b,
      prob_a = prob_a,
      prob_b = prob_b
    )
  }, ignoreNULL = TRUE)

  output$prob_a <- renderText({
    if (input$predict_btn == 0) return("-")
    pr <- prediction_result()
    if (is.na(pr$prob_a)) "-" else sprintf("%.1f%%", 100 * pr$prob_a)
  })
  output$prob_b <- renderText({
    if (input$predict_btn == 0) return("-")
    pr <- prediction_result()
    if (is.na(pr$prob_b)) "-" else sprintf("%.1f%%", 100 * pr$prob_b)
  })
  output$verdict <- renderText({
    if (input$predict_btn == 0) {
      return("Click Compare Predictions to see results.")
    }
    pr <- prediction_result()
    format_verdict(pr$prob_a, pr$prob_b, pr$name_a, pr$name_b)
  })
  output$predict_plot <- renderPlot({
    pr <- if (input$predict_btn == 0) NULL else tryCatch(prediction_result(), error = function(e) NULL)
    build_predict_plot(pr)
  })
  output$test_perf <- renderText({ test_perf_text })
}

# ---------------------------------------------------------
# 8. Run
# ---------------------------------------------------------

shinyApp(ui = ui, server = server)
