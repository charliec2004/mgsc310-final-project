# ---------------------------------------------------------
# Mini AI Project: Shiny App Template
# Team Name: Team Money
# Team Members: Charlie, Aria, Ryan, Steven
# ---------------------------------------------------------

library(shiny)
library(tidyverse)
library(rsample)

# Add any other packages you need here.
# Examples:
# library(caret)
# library(randomForest)
# library(rpart)
# library(pROC)

# ---------------------------------------------------------
# 1. Load data
# ---------------------------------------------------------

# IMPORTANT:
# Use a relative file path.
# Replace this file name with your actual dataset file name.

my_data <- read.csv("data/your_dataset_name.csv", stringsAsFactors = TRUE)

# ---------------------------------------------------------
# 2. Clean / prepare data
# ---------------------------------------------------------

# Replace these names with variables from your project.
# Your outcome should be the outcome variable from your final project
# or a simplified version of it.

my_data_clean <- my_data %>%
  drop_na()

# Example:
# my_data_clean <- my_data_clean %>%
#   mutate(
#     outcome = as.factor(outcome),
#     categorical_predictor = as.factor(categorical_predictor)
#   )

# ---------------------------------------------------------
# 3. Train/test split
# ---------------------------------------------------------

set.seed(310)

data_split <- initial_split(my_data_clean, prop = 0.80)
train_data <- training(data_split)
test_data  <- testing(data_split)

# ---------------------------------------------------------
# 4. Train model
# ---------------------------------------------------------

# Replace this example model with your own model.
# The model must be trained on train_data, not the full dataset.

# Regression example:
# model <- lm(
#   outcome ~ predictor_1 + predictor_2 + predictor_3,
#   data = train_data
# )

# Classification example:
# model <- glm(
#   outcome ~ predictor_1 + predictor_2 + predictor_3,
#   data = train_data,
#   family = "binomial"
# )

# For your submitted app, replace this with a real model:
model <- NULL

# Optional but recommended: create simple test-set predictions
# and calculate one performance metric.
# Example for regression:
# test_data <- test_data %>%
#   mutate(prediction = predict(model, newdata = test_data))
#
# rmse <- sqrt(mean((test_data$outcome - test_data$prediction)^2))

# ---------------------------------------------------------
# 5. User interface
# ---------------------------------------------------------

ui <- fluidPage(
  
  titlePanel("Mini AI Project: Prediction App"),
  
  sidebarLayout(
    
    sidebarPanel(
      h4("Prediction Inputs"),
      
      # Replace these with at least 3 predictors from your model.
      numericInput("predictor_1", "Predictor 1:", value = 10),
      numericInput("predictor_2", "Predictor 2:", value = 5),
      numericInput("predictor_3", "Predictor 3:", value = 1),
      
      # Example categorical input.
      # Make sure choices come from the training data factor levels.
      # selectInput(
      #   "categorical_predictor",
      #   "Categorical Predictor:",
      #   choices = levels(train_data$categorical_predictor)
      # ),
      
      actionButton("predict_button", "Generate Prediction"),
      
      hr(),
      
      h4("Explore the Data"),
      
      # This is an additional interactive element beyond the prediction button.
      # Replace this with something meaningful for your app.
      sliderInput(
        "sample_size",
        "Number of observations shown in plot:",
        min = 50,
        max = min(1000, nrow(my_data_clean)),
        value = min(300, nrow(my_data_clean)),
        step = 50
      )
    ),
    
    mainPanel(
      
      tabsetPanel(
        
        tabPanel(
          "Explore Data",
          h3("Outcome-Connected Visualization"),
          plotOutput("main_plot"),
          p(
            strong("What to notice: "),
            "Replace this sentence with a clear caption explaining what the plot shows and why it matters for your outcome variable."
          )
        ),
        
        tabPanel(
          "Make a Prediction",
          h3("Model Prediction"),
          verbatimTextOutput("prediction_output"),
          
          h3("How to Interpret the Prediction"),
          p("Replace this with a plain-English explanation of the prediction. Is it a predicted value, a probability, a risk level, or a predicted category? Be honest about what the model can and cannot tell the user.")
        ),
        
        tabPanel(
          "About",
          h3("About This App"),
          p("Briefly explain what your app does, who the decision-maker is, and what decision or problem the app supports.")
        )
      )
    )
  )
)

# ---------------------------------------------------------
# 6. Server
# ---------------------------------------------------------

server <- function(input, output) {
  
  # Example filtered data for an interactive plot.
  # Replace this with a filter that makes sense for your dataset.
  plot_data <- reactive({
    my_data_clean %>%
      slice_head(n = input$sample_size)
  })
  
  # Visualization requirement:
  # At least one plot must connect directly to the outcome variable.
  output$main_plot <- renderPlot({
    
    # Replace outcome and predictor_1 with real variable names.
    # Example for numeric outcome:
    # ggplot(plot_data(), aes(x = predictor_1, y = outcome)) +
    #   geom_point(alpha = 0.6) +
    #   labs(
    #     title = "Outcome vs. Key Predictor",
    #     x = "Key Predictor",
    #     y = "Outcome Variable"
    #   )
    
    ggplot(plot_data(), aes(x = 1:nrow(plot_data()))) +
      geom_bar() +
      labs(
        title = "Replace with an outcome-connected visualization",
        x = "Replace x-axis",
        y = "Replace y-axis"
      )
  })
  
  output$prediction_output <- renderPrint({
    
    input$predict_button
    
    isolate({
      
      # Replace this with the new observation your model needs.
      # Variable names must exactly match the model formula.
      # Include at least 3 predictors.
      
      new_observation <- data.frame(
        predictor_1 = input$predictor_1,
        predictor_2 = input$predictor_2,
        predictor_3 = input$predictor_3
      )
      
      # If using categorical variables, preserve factor levels like this:
      #
      # new_observation <- data.frame(
      #   predictor_1 = input$predictor_1,
      #   predictor_2 = input$predictor_2,
      #   categorical_predictor = factor(
      #     input$categorical_predictor,
      #     levels = levels(train_data$categorical_predictor)
      #   )
      # )
      
      # Replace this with the correct prediction code for your model.
      #
      # Regression:
      # prediction <- predict(model, newdata = new_observation)
      #
      # Logistic regression probability:
      # prediction <- predict(model, newdata = new_observation, type = "response")
      #
      # Classification model:
      # prediction <- predict(model, newdata = new_observation, type = "class")
      
      prediction <- "Replace this line with your model prediction."
      
      prediction
    })
  })
}

shinyApp(ui = ui, server = server)