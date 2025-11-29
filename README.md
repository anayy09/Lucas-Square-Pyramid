# Lucas Square Pyramid - Distributed Actor-Based Solution

A Gleam implementation of the **Lucas Square Pyramid Problem** using the Actor model for parallel and distributed computation. This project is developed as part of the Distributed Operating System Principles (COP5615) course at the University of Florida.

## Problem Description

The Lucas Square Pyramid problem seeks to find starting positions where a sequence of `k` consecutive perfect squares sums to a perfect square:

$$\sum_{i=n}^{n+k-1} i^2 = m^2$$

For example, when `k = 24`, starting at `n = 1`:
$$1^2 + 2^2 + 3^2 + \ldots + 24^2 = 70^2 = 4900$$

## Features

- **Sequential Implementation**: Basic iterative approach for finding Lucas sequences
- **Actor-Based Parallel Implementation**: Distributed computation using Gleam's OTP actors
- **Configurable Work Distribution**: Adjustable number of workers and work unit sizes
- **Efficient Square Root Calculation**: Binary search-based integer square root
- **Perfect Square Detection**: Fast verification using computed square roots

## Architecture

The project uses a **Boss-Worker** actor pattern:

```
┌─────────────────────────────────────────────────────────────┐
│                         BOSS ACTOR                          │
│  - Receives results from workers                            │
│  - Tracks worker completion                                 │
│  - Aggregates and outputs sorted results                    │
└─────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │ ResultFound(n)     │ ResultFound(n)     │ WorkerDone
         │ WorkerDone         │ WorkerDone         │
┌────────┴────────┐ ┌────────┴────────┐ ┌────────┴────────┐
│   WORKER 1      │ │   WORKER 2      │ │   WORKER N      │
│  range [1..u]   │ │ range [u+1..2u] │ │ range [...]     │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### Key Components

| Function | Description |
|----------|-------------|
| `lucas(n, k)` | Sequential solution printing all valid starting positions |
| `lucas_actor(n, k, workers, work_unit)` | Parallel actor-based solution |
| `perfect_square(x)` | Checks if a number is a perfect square |
| `sum_k_squares(n)` | Computes sum of squares from 1 to n using formula: $\frac{n(n+1)(2n+1)}{6}$ |

## Installation

### Prerequisites

- [Gleam](https://gleam.run/) (v1.0.0 or later)
- [Erlang/OTP](https://www.erlang.org/) (v26 or later recommended)

### Setup

```sh
# Clone the repository
git clone <repository-url>
cd DOSP-Project-1

# Install dependencies
gleam deps download

# Build the project
gleam build
```

## Usage

### Running the Program

```sh
gleam run -- <N> <K> <WORKERS> <WORK_UNIT>
```

**Parameters:**
- `N` - Upper bound for starting positions to check
- `K` - Number of consecutive squares in the sequence
- `WORKERS` - Number of parallel worker actors
- `WORK_UNIT` - Size of work chunk assigned to each worker per round

### Examples

```sh
# Find all sequences of 24 consecutive squares (up to n=1000000) 
# that sum to a perfect square using 8 workers
gleam run -- 1000000 24 8 1000

# Smaller test case
gleam run -- 100 2 4 10
```

### Running Tests

```sh
gleam test
```

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `gleam_stdlib` | >= 0.44.0 | Standard library functions |
| `gleam_erlang` | >= 1.3.0 | Erlang interop and process handling |
| `gleam_otp` | >= 1.1.0 | Actor model implementation |
| `argv` | >= 1.0.2 | Command-line argument parsing |
| `gtempo` | >= 7.2.2 | Time utilities |
| `gleeunit` | >= 1.0.0 | Testing framework (dev) |

## Algorithm Details

### Sliding Window Optimization

Instead of recalculating the sum for each starting position, the algorithm uses a sliding window approach:

```
sum(i+1, k) = sum(i, k) - i² + (i+k)²
```

This reduces the per-iteration complexity from O(k) to O(1).

### Integer Square Root

Uses binary search to compute the integer square root efficiently:

```gleam
pub fn sqrt(x: Int) -> Int {
  sqrt_loop(0, x, x, -1)
}
```

### Work Distribution

Ranges are assigned to workers in a round-robin fashion, ensuring balanced load distribution across all workers.

## Project Structure

```
DOSP-Project-1/
├── src/
│   └── lucas.gleam      # Main implementation
├── test/
│   └── lucas_test.gleam # Unit tests
├── gleam.toml           # Project configuration
├── manifest.toml        # Dependency lock file
└── README.md            # This file
```

## Course Information

- **Course**: COP5615 - Distributed Operating System Principles
- **Semester**: Fall 2025
- **University**: University of Florida

## License

This project is developed for educational purposes as part of coursework at the University of Florida.