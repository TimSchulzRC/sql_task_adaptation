import os
import random
import matplotlib.pyplot as plt
import numpy as np
import tqdm

task_count = 10
learner_count = 10000


def rgbeta(n: int, mean: float, var: float, min: float = 0, max: float = 1) -> float:
    dmin = mean - min
    dmax = max - mean

    if dmin <= 0 or dmax <= 0:
        raise ValueError(f"mean must be between min = {min} and max = {max}")

    if var >= dmin * dmax:
        raise ValueError(
            f"var must be less than (mean - min) * (max - mean) = {dmin * dmax}")

    mx = (mean - min) / (max - min)
    vx = var / (max - min) ** 2

    a = ((1 - mx) / vx - 1 / mx) * mx ** 2
    b = a * (1 / mx - 1)

    x = np.random.beta(a, b, n)
    y = (max - min) * x + min

    return y.tolist()


def calc_complexity(frequency, regulation=0.5, weight=1):
    return (frequency * weight) ** (1 / regulation) / ((1 + (frequency * weight)) ** (1 / regulation))

def calc_frequency(complexity, regulation=0.5, weight=1):
    return (-complexity/(complexity-1))**regulation


def create_random_task(dql_model: dict[str, list[str]]):
    return {key: [random.randint(0, 7) for _ in dql_model[key]] for key in dql_model}


def create_optimal_task(dql_model: dict[str, list[str]], learner_competency: dict[str, list[float]], scaffolding_bonus: dict[str, list[float]]):
    return {key: [np.clip(learner_competency[key][i] + scaffolding_bonus[key][i], 0, 1) * 7 for i in range(len(dql_model[key]))] for key in dql_model}


def calc_task_complexities(task: dict[str, list[int]]):
    return {key: calc_complexity_for_category(category) for key, category in task.items()}


def calc_complexity_for_category(category: list[int]):
    return list(calc_complexity(frequency, regulation=0.5, weight=1) for frequency in category)


def create_learner_scaffolded_competence_bonuses(dql_model: dict[str, list[str]]):
    return {key: rgbeta(len(dql_model[key]), 0.1, 0.002, 0, 1) for key in dql_model}


def sample_from_snd_vectorized_and_normalize(X: list[float], mean=0, sd=1):
    # Generate random normal samples and normalize using min-max
    samples = np.random.normal(mean, sd, len(X))
    min_x = min(samples)
    max_x = max(samples)
    return ((samples - min_x) / (max_x - min_x)).tolist()


def create_learner_competencies(dql_model: dict[str, list[str]]):
    return {key: sample_from_snd_vectorized_and_normalize(dql_model[key]) for key in dql_model}


def create_learner_population(learner_count: int, task_count: int, dql_model: dict[str, list[str]]):
    return {
        "learner_competencies": [create_learner_competencies(dql_model) for _ in range(learner_count)],
        "scaffolding_competence_bonus_per_step_and_learner": [[create_learner_scaffolded_competence_bonuses(dql_model) for _ in range(learner_count)] for _ in range(task_count)]
    }


def calculate_delta(learner_competency: dict[str, list[str]], task_complexities: dict[str, list[str]], scaffolding_bonus: dict[str, list[str]]):
    result = {}
    for key in learner_competency:
        result[key] = []
        for i in range(len(learner_competency[key])):
            k = learner_competency[key][i]
            c = task_complexities[key][i]
            t = scaffolding_bonus[key][i]
            if (c <= k or c > k + t):
                result[key].append(0)
            else:
                result[key].append(c - k)
    return result


def add_delta_to_competency(competency: dict[str, list[str]], delta: dict[str, list[str]]):
    return {key: [competency[key][i] + delta[key][i] for i in range(len(competency[key]))] for key in competency}


def simulate_task_adaptation(task_count: int, learner_count: int, dql_model: dict[str, list[str]]):

    learner_population = create_learner_population(
        learner_count, task_count, dql_model)

    simulationLog = [{
        "tasks": [],
        "competencies": [],
        "scaffolding_bonuses": [],
        "deltas": []
    } for _ in range(learner_count)]

    for i in range(task_count):
        for j in range(learner_count):
            learner_competency = learner_population["learner_competencies"][j]
            scaffolding_bonus = learner_population["scaffolding_competence_bonus_per_step_and_learner"][i][j]

            # Hier wird ein Task, bzw. die Parametrisierung für einen Task zufällig gewürfelt.
            # Stattdessen soll dies ein Optimierungsalgorithmus tun.
            # Der Optimierungsalgorithmus darf folgende Informationen bekommen:
            # - delta-Historie <- ggf. calc_aggregated_competency rekursiv anwenden, damit ein skalarer Wert je Aufgabe entsteht
            # - parameter-Historie
            # ToDo: Optimierungsalgorithmus einsetzen und Informationen übergeben
            parameter_history = simulationLog[j]["tasks"]
            delta_history = simulationLog[j]["deltas"]

            # task_parameters = optimize_task_parameters(
            #     dql_model, parameter_history, delta_history)

            task = create_random_task(dql_model)
            # task = create_optimal_task(
            #     dql_model, learner_competency, scaffolding_bonus)

            # print(task)

            task_complexities = calc_task_complexities(task)
            delta = calculate_delta(
                learner_competency, task_complexities, scaffolding_bonus)

            # update the learner competency in the global learner population
            learner_population["learner_competencies"][j] = add_delta_to_competency(
                learner_competency, delta)

            simulationLog[j]["tasks"].append(task)
            simulationLog[j]["competencies"].append(learner_competency)
            simulationLog[j]["scaffolding_bonuses"].append(scaffolding_bonus)
            simulationLog[j]["deltas"].append(delta)

    return simulationLog


def plot_simulation_log(simulationLog: dict[str, list[list[float]]], dql_model: dict[str, list[str]], learnerId: int):
    plt.figure(figsize=(16, 9))
    colors = ['b', 'g', 'r', 'c', 'm', 'y', 'k']
    for i, key in enumerate(dql_model):
        color = colors[i % len(colors)]

        aggregated_competency_values = []
        aggregated_task_values = []
        aggregated_competency_plus_bonus_values = []
        for i in range(task_count):
            # Get competency value
            competency_values = simulationLog[learnerId]["competencies"][i][key]
            competency_aggregated = sum(
                competency_values)/len(competency_values)
            aggregated_competency_values.append(competency_aggregated)

            # Get task complexity value
            task_values = calc_task_complexities(
                simulationLog[learnerId]["tasks"][i])[key]
            task_aggregated = sum(task_values)/len(task_values)
            aggregated_task_values.append(task_aggregated)

            scaffolding_bonus_values = simulationLog[learnerId]["scaffolding_bonuses"][i][key]
            # Add the scaffolding bonus to the competency value
            competency_plus_bonus_values = [
                a + b for a, b in zip(scaffolding_bonus_values, competency_values)]
            competency_plus_bonus_aggregated = sum(
                competency_plus_bonus_values)/len(competency_plus_bonus_values)
            aggregated_competency_plus_bonus_values.append(
                competency_plus_bonus_aggregated)

        plt.plot(range(task_count), aggregated_competency_values,
                 color=color, label=f'{key} competency')
        plt.plot(range(task_count), aggregated_task_values,
                 '.', color=color, label=f'{key} task')
        plt.plot(range(task_count), aggregated_competency_plus_bonus_values,
                 '--', color=color, label=f'{key} competency + scaffolding bonus')

    plt.ylim(0, 1)
    plt.xlim(0, task_count-1)
    plt.ylabel("Competency")
    plt.xlabel("Step")
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.tight_layout()
    # remove old files
    os.remove(f"sql_task_adaptation_{learnerId}.png")
    plt.savefig(
        f"sql_task_adaptation_{learnerId}.png", dpi=300, bbox_inches="tight")


dql_model = {
    "join": ["inner_join", "outer_join", "self_join"],
    "nesting": ["cte", "correlated_subquery", "uncorrelated_subquery"],
    "predicates": ["basic_operators", "logical_operators", "set_operators"]
}


simulationLog = simulate_task_adaptation(
    task_count, learner_count, dql_model)

# for i in range(learner_count):
#     plot_simulation_log(simulationLog, dql_model, i)

# encode params to number between 0 and 342
def encodeParams(params):
    return params[0]*8**2 + params[1]*8**1 + params[2]*8**0

def train_test_split(data, train_size=.7, shuffle=True):
    if shuffle:
        random.shuffle(data)
    boundary = round(len(data) * train_size)
    return data[: boundary], data[boundary:]

sequences = []

for dql_category in dql_model:
    for studentId in range(len(simulationLog)):
        tasks = []
        solved = []
        for taskIndex in range(task_count):
            params = simulationLog[studentId]["tasks"][taskIndex][dql_category]
            skillDelta = simulationLog[studentId]["deltas"][taskIndex][dql_category]
            taskId = encodeParams(params)
            learnEffect = any(value > 0 for value in skillDelta)
            tasks.append(taskId)
            solved.append(1 if learnEffect else 0 )
            
            
            
            # skillId = skillParams[0] * skillParams[1] * skillParams[2]
            # step = [0] * (NUM_QUESTION*2)
            # if (learneffect):
            #     step[skillId] = 1
            # else:
            #     step[skillId + 342] = 1
        sequences.append((tasks, solved))
    

train_sequences, test_sequences = train_test_split(sequences)


MAX_STEP = 50
NUM_QUESTIONS = 512


def encode_onehot(sequences, max_step, num_questions):
    result = []

    for q, a in tqdm.tqdm(sequences, 'convert to one-hot format: '):
        length = len(q)
        # append questions' and answers' length to an integer multiple of max_step
        mod = 0 if length % max_step == 0 else (max_step - length % max_step)
        onehot = np.zeros(shape=[length + mod, 2 * num_questions])
        for i, q_id in enumerate(q):
            index = int(q_id if a[i] > 0 else q_id + num_questions)
            onehot[i][index] = 1
        result = np.append(result, onehot)
    
    return result.reshape(-1, max_step, 2 * num_questions)

# reduce the amount of data for example running faster
percentage = 0.05
train_data = encode_onehot(train_sequences[: int(len(train_sequences) * percentage)], MAX_STEP, NUM_QUESTIONS)
test_data = encode_onehot(test_sequences[: int(len(test_sequences) * percentage)], MAX_STEP, NUM_QUESTIONS)

print(test_data.shape)

np.save('train_data.npy', train_data)
np.save('test_data.npy', test_data)