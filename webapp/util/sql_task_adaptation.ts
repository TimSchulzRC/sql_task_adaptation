import {
  DqlModel,
  LearnerPopulation,
  SimulationLog,
  SingleLearnerCompetenceBonus,
  SingleLearnerCompetencies,
  SingleLearnerDeltas,
  SingleLearnerTask,
  ValueStructure,
} from "@/types/sql_task_adaptation";
import { minMaxNorm, rgnormal, rnorm, sum_till_max } from "@/util/math";

const simParamComplexityConvergationFactor = 0.5;
export const simplifiedDqlPartialCompetencySyntaxMap: DqlModel = [
  {
    category: "join",
    items: ["inner_join", "outer_join", "self_join"],
  },
  {
    category: "nesting",
    items: ["cte", "correlated_subquery", "uncorrelated_subquery"],
  },
  {
    category: "predicates",
    items: ["basic_operators", "logical_operators", "set_operators"],
  },
];

const simParamScaffoldingBonusDistribution = [0.1, 0.002, 0, 0.2];

function sampleFromSndVectorizedAndNormalize(
  category: DqlModel[0],
  mean = 0,
  stdev = 1
) {
  return minMaxNorm(rnorm(category.items.length, mean, stdev));
}

function createLearnerCompetencies(
  dqlModel: DqlModel
): SingleLearnerCompetencies {
  return dqlModel.map((category) => {
    return {
      category: category.category,
      syntaxElementValues: sampleFromSndVectorizedAndNormalize(category),
    };
  });
}

function createLearnerPopulationCompetencies(
  learnerCount: number,
  dqlModel: DqlModel
): SingleLearnerCompetencies[] {
  return Array(learnerCount).fill(dqlModel).map(createLearnerCompetencies);
}

function sampleFromGnorm(dqlModelElement: DqlModel[0]) {
  return rgnormal(
    dqlModelElement.items.length,
    simParamScaffoldingBonusDistribution[0], // mean
    simParamScaffoldingBonusDistribution[1], // variance
    simParamScaffoldingBonusDistribution[2], // min
    simParamScaffoldingBonusDistribution[3] // max
  );
}

function createLearnderScaffoldedCompetenceBonuses(
  dqlModel: DqlModel
): SingleLearnerCompetenceBonus {
  return dqlModel.map((category) => {
    return {
      category: category.category,
      syntaxElementValues: sampleFromGnorm(category),
    };
  });
}

function createScaffoldingCompetenceBonusPerStep(
  learnerCount: number,
  dqlModel: DqlModel
): SingleLearnerCompetenceBonus[] {
  return Array(learnerCount)
    .fill(dqlModel)
    .map(createLearnderScaffoldedCompetenceBonuses);
}

function setupSimulation(
  taskCount: number,
  learnerCount: number,
  dqlModel: DqlModel
) {
  const learnerPopulationCompetencies = createLearnerPopulationCompetencies(
    learnerCount,
    dqlModel
  );

  const scaffoldingCompetenceBonusPerStepAndLearner = Array(taskCount)
    .fill(null)
    .map(() => {
      return createScaffoldingCompetenceBonusPerStep(learnerCount, dqlModel);
    });
  return {
    learnerPopulationCompetencies,
    scaffoldingCompetenceBonusPerStepAndLearner,
  };
}
function generateRandomTask(dqlModel: DqlModel): SingleLearnerTask {
  return dqlModel.map((category) => {
    return {
      category: category.category,
      syntaxElementValues: Array(category.items.length)
        .fill(null)
        .map(() => Math.floor(Math.random() * 8)),
    };
  });
}

function approximateComplexity(
  frequency: number,
  r = simParamComplexityConvergationFactor
) {
  return frequency ** (1 / r) / (10 + frequency ** (1 / r));
}

function approximateComplexityVectorized(
  category: SingleLearnerTask[0],
  r = simParamComplexityConvergationFactor
) {
  return category.syntaxElementValues.map((difficulty) =>
    approximateComplexity(difficulty, r)
  );
}

function determineDelta(
  complexity: number,
  competenceWithoutScaffolding: number,
  scaffoldingCompetenceBonus: number
): number {
  if (
    isAboveCompetenceAndBelowScaffoldedCompetence(
      complexity,
      competenceWithoutScaffolding,
      scaffoldingCompetenceBonus
    )
  ) {
    return complexity - competenceWithoutScaffolding;
  }
  return 0;
}

// Vectorized version of determineDelta
function determineDeltaVectorized(
  complexities: number[],
  competencesWithoutScaffolding: number[],
  scaffoldingCompetenceBonuses: number[]
): number[] {
  return complexities.map((complexity, index) => {
    return determineDelta(
      complexity,
      competencesWithoutScaffolding[index],
      scaffoldingCompetenceBonuses[index]
    );
  });
}

// Checks if complexity is above competence and below scaffolded competence
function isAboveCompetenceAndBelowScaffoldedCompetence(
  complexity: number,
  competenceWithoutScaffolding: number,
  competenceBonusFromScaffolding: number
): boolean {
  const competenceWithScaffolding = sum_till_max([
    competenceWithoutScaffolding,
    competenceBonusFromScaffolding,
  ]);
  return (
    competenceWithoutScaffolding < complexity &&
    competenceWithScaffolding > complexity
  );
}

function compareCompetenceAndComplexity(
  taskComplexity: SingleLearnerTask,
  learnerCompetencies: SingleLearnerCompetencies,
  scaffoldingCompetenceBonuses: SingleLearnerCompetenceBonus,
  aggregated: boolean = true
): SingleLearnerDeltas {
  if (aggregated) {
    // TODO: Überlegen ob sinnvoll, was das tatsächlich simulieren würde und anschließend ggf. implementieren.
  }

  return taskComplexity.map((category, index) => {
    return {
      category: category.category,
      syntaxElementValues: determineDeltaVectorized(
        category.syntaxElementValues,
        learnerCompetencies[index].syntaxElementValues,
        scaffoldingCompetenceBonuses[index].syntaxElementValues
      ),
    };
  });
}

export function addValueStructuresElementwise(
  a: ValueStructure,
  b: ValueStructure
): ValueStructure {
  return a.map((category, index) => {
    return {
      category: category.category,
      syntaxElementValues: category.syntaxElementValues.map(
        (aVal, i) => aVal + b[index].syntaxElementValues[i]
      ),
    };
  });
}

function executeSimulation(
  learnerPopulation: LearnerPopulation,
  dqlModel: DqlModel
) {
  const {
    learnerPopulationCompetencies,
    scaffoldingCompetenceBonusPerStepAndLearner,
  } = learnerPopulation;

  const taskCount = scaffoldingCompetenceBonusPerStepAndLearner.length;
  const learnerCount = learnerPopulationCompetencies.length;

  const simulationLog: SimulationLog = Array(learnerCount).fill({
    tasks: [],
    competencies: [],
    scaffolding_bonuses: [],
    deltas: [],
  });

  // for each step loop over all learners and generate a task
  for (let i = 0; i < taskCount; i++) {
    for (let j = 0; j < learnerCount; j++) {
      // Hier wird ein Task, bzw. die Parametrisierung für einen Task zufällig gewürfelt.
      // Stattdessen soll dies ein Optimierungsalgorithmus tun.
      // Der Optimierungsalgorithmus darf folgende Informationen bekommen:
      // - delta-Historie <- ggf. calc_aggregated_competency rekursiv anwenden, damit ein skalarer Wert je Aufgabe entsteht
      // - parameter-Historie
      // ToDo: Optimierungsalgorithmus einsetzen und Informationen übergeben

      const prevTasks = simulationLog[j].tasks;
      console.log(simulationLog[j].deltas);

      const task = generateRandomTask(dqlModel);

      const taskComplexity: SingleLearnerTask = task.map((category) => {
        return {
          category: category.category,
          syntaxElementValues: approximateComplexityVectorized(category),
        };
      });
      const competencies = learnerPopulationCompetencies[j];
      const scaffoldingCompetenceBonuses =
        scaffoldingCompetenceBonusPerStepAndLearner[i][j];
      const delta = compareCompetenceAndComplexity(
        taskComplexity,
        competencies,
        scaffoldingCompetenceBonuses
      );
      const updatedCompetencies = addValueStructuresElementwise(
        delta,
        competencies
      );
      learnerPopulationCompetencies[j] = updatedCompetencies;
      simulationLog[j].tasks.push(taskComplexity);
      simulationLog[j].competencies.push(updatedCompetencies);
      simulationLog[j].deltas.push(delta);
      simulationLog[j].scaffolding_bonuses.push(scaffoldingCompetenceBonuses);
    }
  }
  return simulationLog;
}

export function setupAndExecuteSimulation(
  taskCount: number,
  learnerCount: number,
  dqlModel: DqlModel
) {
  const learnerPopulation = setupSimulation(taskCount, learnerCount, dqlModel);
  const simulationLog = executeSimulation(learnerPopulation, dqlModel);
  return simulationLog;
}
