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
