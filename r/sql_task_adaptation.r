library(ggplot2)
library(foreach)
library(iterators)

# Generates random numbers from a beta distribution with specified mean and variance
rgbeta <- function(n, mean, var, min = 0, max = 1) {
    dmin <- mean - min
    dmax <- max - mean

    if (dmin <= 0 || dmax <= 0) {
        stop(paste("mean must be between min =", min, "and max =", max))
    }

    if (var >= dmin * dmax) {
        stop(paste("var must be less than (mean - min) * (max - mean) =", dmin * dmax))
    }

    mx <- (mean - min) / (max - min)
    vx <- var / (max - min)^2

    a <- ((1 - mx) / vx - 1 / mx) * mx^2
    b <- a * (1 / mx - 1)

    x <- rbeta(n, a, b)
    y <- (max - min) * x + min

    return(y)
}

# Approximates the complexity of a task based on its frequency
approximate_complexity <- function(frequency, r = SIM_PARAM_COMPLEXITY_CONVERGATION_FACTOR) {
    return((frequency**(1 / r)) / (10 + (frequency**(1 / r))))
}

# Vectorized version of approximate_complexity
approximate_complexity_vectorized <- function(frequencies, r = SIM_PARAM_COMPLEXITY_CONVERGATION_FACTOR) {
    return(lapply(frequencies, approximate_complexity))
}

# Normalizes a vector using min-max normalization
min_max_norm <- function(X) {
    min.x <- min(X)
    max.x <- max(X)
    return((X - min.x) / (max.x - min.x))
}

# Samples from a standard normal distribution and normalizes the result
sample_from_snd_vectorized_and_normalize <- function(X, mean = 0, sd = 1) {
    return(min_max_norm(rnorm(length(X), mean, sd)))
}

# Sums elements until a maximum value is reached
sum_till_max <- function(..., max = 1) {
    L <- list(...)
    df <- as.data.frame(do.call(cbind, L))
    df[[3]] <- df[[1]] + df[[2]]
    df[[3]][df[3] > 1] <- 1
    return(as.list(df[[3]]))
}

# returns samples from a generalized beta distribution
sample_from_gbeta <- function(l) {
    return(rgbeta(
        length(l),
        SIM_PARAM_SCAFFOLDING_BONUS_DISTRIBUTION[[1]],
        SIM_PARAM_SCAFFOLDING_BONUS_DISTRIBUTION[[2]],
        SIM_PARAM_SCAFFOLDING_BONUS_DISTRIBUTION[[3]],
        SIM_PARAM_SCAFFOLDING_BONUS_DISTRIBUTION[[4]]
    ))
}

# Creates learner competencies
create_learner_competencies <- function(l) {
    return(lapply(l, sample_from_snd_vectorized_and_normalize))
}

# Creates scaffolded competence bonuses for learners
create_learner_scaffolded_competence_bonuses <- function(l) {
    return(lapply(l, sample_from_gbeta))
}

# Calculates scaffolded competencies for learners
calc_learner_scaffolded_competencies <- function(competencies, bonuses) {
    return(mapply(sum_till_max, competencies, bonuses, simplify = FALSE))
}

# Creates a population of learners
create_learner_population <- function(n, dql_model) {
    return(replicate(n,
        {
            learner_competencies <- create_learner_competencies(dql_model)
        },
        simplify = FALSE
    ))
}

# Creates scaffolded competence bonuses for each step
create_scaffolding_competence_bonus_per_step <- function(a, dql_model) {
    return(replicate(a,
        {
            scaffolding_competence_bonus <- create_learner_scaffolded_competence_bonuses(dql_model)
        },
        simplify = FALSE
    ))
}

# Sets up the simulation environment
setup_simulation <- function(A, N, dql_model) {
    learner_competencies <- create_learner_population(N, dql_model)
    scaffolding_competence_bonus_per_step_and_learner <- replicate(A,
        {
            scaffolding_competence_bonus_per_step <- create_scaffolding_competence_bonus_per_step(N, dql_model)
        },
        simplify = FALSE
    )

    return(list(learner_competencies = learner_competencies, scaffolding_competence_bonus_per_step_and_learner = scaffolding_competence_bonus_per_step_and_learner))
}

# Determines the delta between complexity and competence
determine_delta <- function(complexity, competence_without_scaffolding, scaffolding_competence_bonus) {
    if (is_above_competence_and_below_scaffolded_competence(complexity, competence_without_scaffolding, scaffolding_competence_bonus)) {
        return(complexity - competence_without_scaffolding)
    }
    return(0)
}

# Vectorized version of determine_delta
determine_delta_vectorized <- function(complexities, competences_without_scaffolding, scaffolding_competence_bonuses) {
    return(unlist(mapply(unlist(determine_delta), unlist(complexities), unlist(competences_without_scaffolding), scaffolding_competence_bonuses, SIMPLIFY = FALSE)))
}

# Checks if complexity is above competence and below scaffolded competence
is_above_competence_and_below_scaffolded_competence <- function(complexity, competence_without_scaffolding, competence_bonus_from_scaffolding) {
    competence_with_scaffolding <- unlist(sum_till_max(competence_without_scaffolding, competence_bonus_from_scaffolding))
    return(competence_without_scaffolding < complexity && competence_with_scaffolding > complexity)
}

# Compares competence and complexity
compare_competence_and_complexity <- function(task_complexity, learner_competencies, scaffolding_competence_bonuses, aggregated = FALSE) {
    if (aggregated == TRUE) {
        # TODO: Überlegen ob sinnvoll, was das tatsächlich simulieren würde und anschließend ggf. implementieren.
        # Zumindest visuell nachvollziehbarer und eingängiger?

        # complexity <- lapply(task_complexity, calc_aggregated_competency)
        # competency <- lapply(learner_competencies, calc_aggregated_competency)
    }

    return(mapply(determine_delta_vectorized, task_complexity, learner_competencies, scaffolding_competence_bonuses, SIMPLIFY = FALSE))
}

# Calculates aggregated competency
calc_aggregated_competency <- function(partial_competencies, weights = NULL) {
    if (is.null(weights)) {
        weights <- rep(1, length(partial_competencies))
    }
    if (is.list(partial_competencies)) {
        partial_competencies <- unlist(partial_competencies)
    }
    return(sum(partial_competencies * weights) / sum(weights))
}

# Updates learner competencies based on delta
update_learner_competencies <- function(delta, learner_competencies) {
    return(mapply(function(delta_per_competency, learner_competency) {
        return(list(unlist(delta_per_competency) + learner_competency))
    }, delta, learner_competencies, SIMPLIFY = FALSE))
}

# Adds two lists element-wise
add_lists_elementwise <- function(list1, list2) {
    add_recursive <- function(elem1, elem2) {
        if (is.list(elem1) && is.list(elem2)) {
            mapply(add_recursive, elem1, elem2, SIMPLIFY = FALSE)
        } else if (is.numeric(elem1) && is.numeric(elem2)) {
            elem1 + elem2
        } else {
            stop("Both lists must have the same structure and numeric elements.")
        }
    }
    add_recursive(list1, list2)
}

# Initializes the log for the simulation
initialize_log <- function(N) {
    return(replicate(N,
        {
            return(list(tasks = list(), competencies = list(), scaffolding_bonuses = list(), deltas = list()))
        },
        simplify = FALSE
    ))
}

# Generates a random task based on the DQL model
random_task <- function(dql_model) {
    return(lapply(dql_model, function(competency) {
        return(sample(
            rep(SIM_PARAM_TASK_RANDOMIZER_INTERVAL[[1]]:SIM_PARAM_TASK_RANDOMIZER_INTERVAL[[2]],
                each = length(competency)
            ),
            size = length(competency),
            replace = TRUE
        ))
    }))
}

fixed_task <- function(dql_model) {
    return(lapply(dql_model, function(competency) {
        return(rep(1, length(competency)))
    }))
}

# Executes the simulation
execute_simulation <- function(learner_population, dql_model) {
    learner_competencies <- learner_population$learner_competencies
    scaffolding_competence_bonus_per_step_and_learner <- learner_population$scaffolding_competence_bonus_per_step_and_learner

    A <- length(scaffolding_competence_bonus_per_step_and_learner)
    N <- length(scaffolding_competence_bonus_per_step_and_learner[[1]])

    simulation_log <- initialize_log(N)

    for (i in 1:A) {
        for (j in 1:N) {
            # Hier wird ein Task, bzw. die Parametrisierung für einen Task zufällig gewürfelt.
            # Stattdessen soll dies ein Optimierungsalgorithmus tun.
            # Der Optimierungsalgorithmus darf folgende Informationen bekommen:
            # - delta-Historie <- ggf. calc_aggregated_competency rekursiv anwenden, damit ein skalarer Wert je Aufgabe entsteht
            # - parameter-Historie
            # ToDo: Optimierungsalgorithmus einsetzen und Informationen übergeben
            task <- random_task(dql_model)
            # task <- fixed_task(dql_model)
            # View(task)

            # print(task)
            task_complexity <- lapply(task, approximate_complexity_vectorized)
            competencies <- learner_competencies[[j]]
            scaffolding_competence_bonuses <- scaffolding_competence_bonus_per_step_and_learner[[i]][[j]]

            delta <- compare_competence_and_complexity(task_complexity, competencies, scaffolding_competence_bonuses)
            updated_competencies <- add_lists_elementwise(delta, competencies)

            # print(delta)

            learner_competencies[[j]] <- updated_competencies

            simulation_log[[j]]$tasks <- append(simulation_log[[j]]$tasks, list(task_complexity))
            simulation_log[[j]]$competencies <- append(simulation_log[[j]]$competencies, list(updated_competencies))
            simulation_log[[j]]$deltas <- append(simulation_log[[j]]$deltas, list(delta))
            simulation_log[[j]]$scaffolding_bonuses <- append(simulation_log[[j]]$scaffolding_bonuses, list(scaffolding_competence_bonuses))
            # View(simulation_log)
        }
    }
    return(simulation_log)
}

# Sets up and executes the simulation
setup_and_execute_simulation <- function(A, N, dql_model) {
    learner_population <- setup_simulation(A, N, dql_model)
    simulation_log <- execute_simulation(learner_population, dql_model)
    return(simulation_log)
}

# Applies a function to competencies in the simulation log
apply_function_to_competencies <- function(component_names, fn) {
    transformed_log <- lapply(component_names, fn)
    names(transformed_log) <- component_names

    return(transformed_log)
}

# Applies a function to competency vectors in the simulation log
apply_function_to_competency_vectors <- function(simulation_log, component_names, fn) {
    return(apply_function_to_competencies(component_names, function(name) {
        lapply(simulation_log[[name]], fn)
    }))
}

# Gets a list of aggregated competencies from the simulation log
get_aggregated_competencies_list <- function(simulation_log, component_names) {
    return(apply_function_to_competency_vectors(simulation_log, component_names, calc_aggregated_competency))
}

# Transforms a nested list in the simulation log
transform_nested_list <- function(simulation_log, component_names) {
    return(apply_function_to_competencies(component_names, function(name) {
        lapply(simulation_log, function(item) unlist(item[[name]], use.names = FALSE))
    }))
}

# Processes a partial log
process_partial_log <- function(partial_log) {
    competency_names <- names(partial_log[[1]])

    stepwise_competency_log <- transform_nested_list(partial_log, competency_names)

    stepwise_aggregated_competency_log <- get_aggregated_competencies_list(stepwise_competency_log, competency_names)
    return(list(stepwise_aggregated_competency_log = stepwise_aggregated_competency_log, competency_names = competency_names))
}

# Plots the deltas for a learner
plot_learner_deltas <- function(learner_id, simulation_log, competencies_to_display) {
    # ToDo: Kummulative Darstellung der deltas? Aggregation auf Aufgabenebene?

    learner_log <- simulation_log[[learner_id]]
    learner_deltas <- learner_log$deltas

    processed_log <- process_partial_log(learner_deltas)

    stepwise_aggregated_competency_log <- processed_log$stepwise_aggregated_competency_log
    competency_names <- processed_log$competency_names

    cl <- rainbow(length(competency_names))

    steps <- seq_along(learner_deltas)

    first_component_df <- data.frame(steps = steps, compenence = stepwise_aggregated_competency_log[[competencies_to_display[[1]]]])

    # convert stepwise_aggregated_competency_log[[competencies_to_display[[1]]]] to array
    arr <- array(unlist(stepwise_aggregated_competency_log[[competencies_to_display[[1]]]]), dim = c(length(learner_deltas), 1))


    # print(stepwise_aggregated_competency_log[[competencies_to_display[[1]]]])
    # View(stepwise_aggregated_competency_log[[competencies_to_display[[1]]]])

    plot(1, type = "n", xlim = c(1, length(learner_deltas)), ylim = c(0, 0.1), xlab = "Steps", ylab = "Competency")

    foreach(competency = competencies_to_display, i = icount()) %do% {
        lines(steps, stepwise_aggregated_competency_log[[competency]], col = cl[[i]])
    }

    legend("topright", legend = competency_names, col = cl, pch = 1)
}

# Plots the simulation per aggregated competency for a learner
plot_learner_simulation_per_aggregated_competency <- function(learner_id, simulation_log, competencies_to_display) {
    learner_log <- simulation_log[[learner_id]]
    # print(learner_log)
    learner_competencies <- learner_log$competencies
    print(learner_competencies)
    learner_bonuses <- learner_log$scaffolding_bonuses
    learner_tasks <- learner_log$tasks

    processed_competency_log <- process_partial_log(learner_competencies)
    stepwise_aggregated_competency_log <- processed_competency_log$stepwise_aggregated_competency_log

    processed_bonuses_log <- process_partial_log(learner_bonuses)
    stepwise_aggregated_bonuses_log <- processed_bonuses_log$stepwise_aggregated_competency_log

    scaffolded_competency_log <- add_lists_elementwise(stepwise_aggregated_competency_log, stepwise_aggregated_bonuses_log)


    processed_task_log <- process_partial_log(learner_tasks)
    stepwise_aggregated_task_log <- processed_task_log$stepwise_aggregated_competency_log

    competency_names <- processed_competency_log$competency_names

    cl <- rainbow(length(competency_names))
    plot(1, type = "n", xlim = c(1, length(learner_competencies)), ylim = c(0, 1), xlab = "Steps", ylab = "Competency")

    foreach(competency = competencies_to_display, i = icount()) %do% {
        lines(1:length(learner_competencies), stepwise_aggregated_competency_log[[competency]], col = cl[i])
        lines(1:length(learner_competencies), scaffolded_competency_log[[competency]], col = cl[i], lty = "dashed")
        points(1:length(learner_competencies), stepwise_aggregated_task_log[[competency]], col = cl[i])
    }

    legend("bottomright", legend = competency_names, col = cl, pch = 1)
}

# DQL partial competency syntax map
dql_partial_competency_syntax_map <- list(
    "join" = list("inner_left_join", "inner_right_join", "left_outer_join", "right_outer_join", "self_join", "cross_join"),
    "nesting" = list("cte", "correlated_subquery_column", "uncorrelated_subquery_column", "correlated_subquery_predicate", "uncorrelated_subquery_predicate", "correlated_subquery_table", "uncorrelated_subquery_predicate"),
    "predicates" = list("exists", "in", "between", "like/wildcard", "any", "all", "basic_operators", "logical_operators"),
    "aggregates" = list("having", "max", "min", "avg", "sum", "count"),
    "duplicates" = list("distinct", "union", "intersect", "except", "group_by"),
    "selection" = list("*", "alias", "concat", "order", "limit")
)

# Simplified DQL partial competency syntax map
simplified_dql_partial_competency_syntax_map <- list(
    "join" = list("inner_join", "outer_join", "self_join"),
    "nesting" = list("cte", "correlated_subquery", "uncorrelated_subquery"),
    "predicates" = list("basic_operators", "logical_operators", "set_operators")
)

# Simulation parameters
SIM_PARAM_SCAFFOLDING_BONUS_DISTRIBUTION <- c(0.1, 0.002, 0, 0.2)
SIM_PARAM_COMPLEXITY_CONVERGATION_FACTOR <- 0.5
SIM_PARAM_TASK_RANDOMIZER_INTERVAL <- list(0, 7)
SIM_PARAM_TASK_COUNT <- 10
SIM_PARAM_LEARNER_COUNT <- 1
SIM_PARAM_DQL_MODEL <- simplified_dql_partial_competency_syntax_map

# Run the simulation and plot the results
simulation_log <- setup_and_execute_simulation(SIM_PARAM_TASK_COUNT, SIM_PARAM_LEARNER_COUNT, SIM_PARAM_DQL_MODEL)
plot_learner_deltas(1, simulation_log, names(SIM_PARAM_DQL_MODEL))
plot_learner_simulation_per_aggregated_competency(1, simulation_log, names(SIM_PARAM_DQL_MODEL))

# Save the plot to a PNG file in the current working directory
# dev.copy(png, "learner_simulation_plot.png")
# dev.off()

print("Sample from gbeta:")
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))
print(sample_from_gbeta(SIM_PARAM_DQL_MODEL))

print("Learner competencies:")
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
print(create_learner_competencies(SIM_PARAM_DQL_MODEL))
