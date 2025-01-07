"use client";
import { SimulationLog } from "@/types/sql_task_adaptation";
import { getAggregatedPartialCompetency } from "@/util/helper";
import { simplifiedDqlPartialCompetencySyntaxMap } from "@/util/sql_task_adaptation";
import {
  CategoryScale,
  Chart as ChartJS,
  Colors,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  Title,
  Tooltip,
} from "chart.js";
import { Line } from "react-chartjs-2";

ChartJS.register(
  Colors,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

export default function Chart({
  simulationLog,
}: {
  simulationLog: SimulationLog;
}) {
  const simParamDqlModel = simplifiedDqlPartialCompetencySyntaxMap;

  const learnerSimLog = simulationLog[0];

  const colors = ["red", "blue", "green", "yellow"];

  const competencyDatasets = simParamDqlModel.map((category, index) => {
    return {
      label: category.category + " (competency)",
      data: learnerSimLog.competencies.map((competency) =>
        getAggregatedPartialCompetency(competency, index)
      ),
      borderColor: colors[index],
    };
  });

  const compenteciesWithBonusesDatasets = simParamDqlModel.map(
    (category, index) => {
      const aggregatedCompetencies = learnerSimLog.competencies.map(
        (competency) => getAggregatedPartialCompetency(competency, index)
      );
      const aggregatedBonuses = learnerSimLog.scaffolding_bonuses.map((bonus) =>
        getAggregatedPartialCompetency(bonus, index)
      );
      return {
        label: category.category + " (competency with bonuses)",
        data: aggregatedCompetencies.map((c, i) => c + aggregatedBonuses[i]),
        borderDash: [5, 5],
        borderColor: colors[index],
      };
    }
  );

  const taskDatasets = simParamDqlModel.map((category, index) => {
    return {
      label: category.category + " (task)",
      data: learnerSimLog.tasks.map((task) =>
        getAggregatedPartialCompetency(task, index)
      ),
      showLine: false,
      pointRadius: 4,
      borderColor: colors[index],
      backgroundColor: colors[index],
    };
  });

  const labels = Array(learnerSimLog.tasks.length)
    .fill(0)
    .map((el, i) => i);

  const datasets = [
    ...competencyDatasets,
    ...compenteciesWithBonusesDatasets,
    ...taskDatasets,
  ];

  const simData = {
    labels: labels,
    datasets,
  };

  const options = {
    aspectRatio: 1,
    responsive: true,
    plugins: {
      legend: {
        position: "top" as const,
      },
      title: {
        display: true,
        text: "Normal Distribution Histogram",
      },
    },
    scales: {
      y: {
        beginAtZero: true,
        title: {
          display: true,
          text: "Competency",
        },
      },
      x: {
        title: {
          display: true,
          text: "Steps",
        },
      },
    },
  };

  return (
    <div className="container mx-auto">
      {/* <div className="col-span-2 lg:col-span-1 h-full">
        <Line options={options} data={deltaData} />
      </div> */}
      <div className="w-full aspect-square">
        <Line options={options} data={simData} className="h-full" />
      </div>
    </div>
  );
}
