export function rgnormal(
  n: number,
  mean: number,
  variance: number,
  min: number,
  max: number
): number[] {
  // Input validation
  const dmin = mean - min;
  const dmax = max - mean;

  if (dmin <= 0 || dmax <= 0) {
    throw new Error(`mean must be between min=${min} and max=${max}`);
  }

  if (variance >= dmin * dmax) {
    throw new Error(
      `variance must be less than (mean - min) * (max - mean) = ${dmin * dmax}`
    );
  }

  // Generate n random samples
  const result: number[] = [];
  for (let i = 0; i < n; i++) {
    const u = Math.random();
    const v = Math.random();

    // Box-Muller transform to get normal distribution
    const z = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);

    // scale to desired mean and standard deviation
    const x = z * Math.sqrt(variance) + mean;

    // clamp to min/max range
    result.push(Math.min(Math.max(x, min), max));
  }

  return result;
}

export function minMaxNorm(X: number[]) {
  const min = Math.min(...X);
  const max = Math.max(...X);
  return X.map((x) => (x - min) / (max - min));
}

export function rnorm(n: number, mean: number, stdev: number) {
  return Array(n)
    .fill(null)
    .map(() => {
      const u = 1 - Math.random(); // Converting [0,1) to (0,1]
      const v = Math.random();
      const z = Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
      // Transform to the desired mean and standard deviation:
      return z * stdev + mean;
    });
}

export function sum_till_max(values: number[], max: number = 1) {
  return values.reduce((acc, curr) => {
    const sum = acc + curr;
    return sum > max ? max : sum;
  }, 0);
}
