import Chart from "@/components/Chart";
import {
  setupAndExecuteSimulation,
  simplifiedDqlPartialCompetencySyntaxMap,
} from "@/util/sql_task_adaptation";
import fs from "fs";

export default function Home() {
  const simParamTaskCount = 50;
  const simParamLearnerCount = 1;
  const simParamDqlModel = simplifiedDqlPartialCompetencySyntaxMap;

  const simulationLog = setupAndExecuteSimulation(
    simParamTaskCount,
    simParamLearnerCount,
    simParamDqlModel
  );

  fs.writeFileSync("simlog.json", JSON.stringify(simulationLog, null, 2));

  return (
    <>
      <Chart simulationLog={simulationLog} />
    </>
  );
}
