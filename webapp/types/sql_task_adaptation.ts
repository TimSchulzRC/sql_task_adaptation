// item is a single sql syntax element
// category is the aggregated category of the item
// itemCompetencies is a vector of the competency of each item
// itemDifficulties is a vector of the difficulty of each item

export type DqlModel = {
  category: string;
  items: string[];
}[];

export type ValueStructure = {
  category: string;
  syntaxElementValues: number[];
}[];

export type SingleLearnerCompetencies = ValueStructure;
export type SingleLearnerDeltas = ValueStructure;
export type SingleLearnerCompetenceBonus = SingleLearnerCompetencies;
export type SingleLearnerTask = ValueStructure;

export type LearnerPopulation = {
  learnerPopulationCompetencies: SingleLearnerCompetencies[];
  scaffoldingCompetenceBonusPerStepAndLearner: SingleLearnerCompetencies[][];
};

export type SimulationLog = {
  tasks: SingleLearnerTask[];
  competencies: SingleLearnerCompetencies[];
  scaffolding_bonuses: SingleLearnerCompetenceBonus[];
  deltas: SingleLearnerDeltas[];
}[];
