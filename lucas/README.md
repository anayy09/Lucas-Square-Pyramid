# lucas

[![Package Version](https://img.shields.io/hexpm/v/lucas)](https://hex.pm/packages/lucas)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/lucas/)

```sh
gleam add lucas@1
```
```gleam
import lucas

pub fn main() -> Nil {
  // TODO: An example of the project in use
}

```

Further documentation can be found at <https://hexdocs.pm/lucas>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

## Project Report (required assignment items)

This project finds starting indices s (1 <= s <= N) such that the sum of
k consecutive squares s^2 + (s+1)^2 + ... + (s+k-1)^2 is itself a
perfect square. The implementation provides both a sequential collector and
an actor-based worker/boss model.

### Work-unit selection

We measured wall-clock time for `lukas 1000000 4` across several work unit
sizes (number of start indices assigned to a worker per message). The runs
were performed on the development machine (detected 8 logical processors).

Summary (wall times measured):

- work_unit = 1  => elapsed ≈ 3.12 s
- work_unit = 10 => elapsed ≈ 2.04 s
- work_unit = 100 => elapsed ≈ 1.03 s  (best)
- work_unit = 1000 => elapsed ≈ 1.06 s
- work_unit = 10000 => elapsed ≈ 2.05 s

Selected best work unit: 100. Rationale: it produced the lowest wall-clock
time in our sweep. Very small units incur messaging overhead; very large
units reduce work distribution granularity and can leave cores idle.

### Result of `lukas 1000000 4`

Command run:

```powershell
gleam run 1000000 4 8 100 > lucas_1e6_4_out.txt
```

Observed output: the program printed no starting indices (the output file is
empty). This means there are no sequences starting between 1 and 1,000,000
of length 4 whose sum of squares is a perfect square.

### Timing and CPU usage (REAL TIME and CPU/REAL ratio)

Representative measured run (work_unit=100, workers=8):

- REAL TIME (wall-clock): ~1.03 seconds (one benchmark run)
- CPU TIME (total processor time): ~0.0156 seconds (measured via process polling)
- CPU_TIME / REAL_TIME ratio: ~0.015 (very small)

Interpretation: the CPU/real ratio is unusually low because the workload for
this particular input is small and the Gleam toolchain/VM startup and
compilation overhead dominate the measured elapsed time when invoking
`gleam run`. To obtain a meaningful CPU/REAL ratio that reflects parallel
speedup, run a heavier problem (larger N or different k) or run a compiled
release artifact (so runtime startup is negligible).

### Largest problem solved

- For this report we ran and validated `N = 1,000,000`, `k = 4` (with
  workers=8 and work_unit=100). The program completed quickly and found no
  matches.

If you want me to push the limits further (for example N=10,000,000 or
produce an OTP release to remove compile/startup overhead), I can run those
benchmarks and update this README with the results.


### How these figures were obtained (commands)

I included a small PowerShell benchmark script at `bench/bench.ps1` that
automates sweeping work_unit values and records wall times. Example usage:

```powershell
# from the `lucas` directory
powershell -NoProfile -ExecutionPolicy Bypass -File .\bench\bench.ps1
# or specify units/workers explicitly
powershell -File .\bench\bench.ps1 -Workers 8 -Units 1,10,100,1000,10000
```

Notes on reproducibility:

- Use `> $null` or redirect to a file to avoid printing large outputs to the
  terminal during benchmarks.
- For accurate CPU/REAL ratios measure a workload large enough to dwarf
  process startup and compilation overhead, or run a precompiled release.

