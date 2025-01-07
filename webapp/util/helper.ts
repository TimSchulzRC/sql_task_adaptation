import { ValueStructure } from "@/types/sql_task_adaptation";

export function aggregateValueStructure(
  competency: ValueStructure,
  index: number
) {
  return (
    competency[index].syntaxElementValues.reduce((acc, curr) => acc + curr, 0) /
    competency[index].syntaxElementValues.length
  );
}

export function getAggregatedPartialCompetency(
  competency: ValueStructure,
  index: number,
  weights?: number[]
): number {
  const partialCompetency = competency[index].syntaxElementValues;
  if (!weights) {
    weights = Array(partialCompetency.length).fill(1);
  }
  return (
    partialCompetency.reduce((acc, curr, i) => acc + curr * weights[i], 0) /
    weights.reduce((acc, curr) => acc + curr, 0)
  );
}
