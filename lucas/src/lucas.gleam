import argv
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result

pub fn sqrt_loop(low l: Int, high h: Int, target t: Int, result r) -> Int {
  //echo r
  case l <= h {
    False -> r
    True -> {
      let mid: Int = { l + h } / 2
      //echo mid
      case mid {
        n if n * n == t -> n
        n if n * n > t -> sqrt_loop(l, mid - 1, t, r)
        n if n * n < t -> sqrt_loop(mid + 1, h, t, n)
        _ -> -11
      }
    }
  }
}

pub fn sq(x: Int) -> Int {
  x * x
}

pub fn sqrt(x: Int) -> Int {
  sqrt_loop(0, x, x, -1)
}

pub fn perfect_square(x: Int) -> Bool {
  let sqrt = sqrt(x)
  sqrt * sqrt == x
}

pub fn sum_k_squares(n: Int) -> Int {
  n * { n + 1 } * { 2 * n + 1 } / 6
}

pub fn lucas_loop(start: Int, sum: Int, n: Int, k: Int) {
  //echo int.to_string(start) <> ", " <> int.to_string(start + k - 1) <> ", " <> int.to_string(sum)

  case start <= n {
    True -> {
      case perfect_square(sum) {
        True -> io.println(int.to_string(start))
        False -> Nil
      }
      lucas_loop(start + 1, sum - sq(start) + sq(start + k), n, k)
    }
    False -> Nil
  }
}

pub fn lucas(n: Int, k: Int) {
  lucas_loop(1, sum_k_squares(k), n, k)
}

type WorkerMsg {
  Work(range_start: Int, range_end: Int, current_sum: Int)
  Shutdown
}

type BossMsg {
  ResultFound(Int)
  WorkerDone
}

pub fn worker_do_range(start: Int, finish: Int, cur_sum: Int, k: Int) {
  case start <= finish {
    True -> {
      case perfect_square(cur_sum) {
        True -> io.println(int.to_string(start))
        False -> Nil
      }
      worker_do_range(start + 1, finish, cur_sum - sq(start) + sq(start + k), k)
    }
    False -> Nil
  }
}

fn worker_loop(state: Int, msg: WorkerMsg) -> actor.Next(Int, WorkerMsg) {
  case msg {
    Work(start, finish, sum) -> {
      // `state` holds k (window size) for worker
      worker_do_range(start, finish, sum, state)
      actor.continue(state)
    }

    Shutdown -> actor.stop()
  }
}

// Start a worker actor returning its subject (private)
fn start_worker(
  k: Int,
) -> Result(actor.Started(process.Subject(WorkerMsg)), actor.StartError) {
  actor.new(k)
  |> actor.on_message(worker_loop)
  |> actor.start
}

fn start_n_workers(
  count: Int,
  k: Int,
) -> List(Result(actor.Started(process.Subject(WorkerMsg)), actor.StartError)) {
  case count <= 0 {
    True -> []
    False -> [start_worker(k), ..start_n_workers(count - 1, k)]
  }
}

fn boss_loop(state: Nil, msg: BossMsg) -> actor.Next(Nil, BossMsg) {
  case msg {
    ResultFound(v) -> {
      // print result
      io.println(int.to_string(v))
      actor.continue(state)
    }
    WorkerDone -> actor.continue(state)
  }
}

// Assign ranges to workers round-robin by rotation (private)
fn assign_ranges(
  worker_subjects: List(
    Result(actor.Started(process.Subject(WorkerMsg)), actor.StartError),
  ),
  n: Int,
  k: Int,
  work_unit: Int,
  start_idx: Int,
) {
  case start_idx <= n {
    False -> Nil
    True -> {
      case worker_subjects {
        [] -> Nil
        [first, ..rest] -> {
          let e = int.min(n, start_idx + work_unit - 1)
          let sum_for_s =
            sum_k_squares(start_idx + k - 1) - sum_k_squares(start_idx - 1)
          case first {
            Ok(actor.Started(pid: _, data: subject)) ->
              actor.send(subject, Work(start_idx, e, sum_for_s))
            _ -> Nil
          }
          // rotate: send next ranges using rest ++ [first]
          assign_ranges(list.append(rest, [first]), n, k, work_unit, e + 1)
        }
      }
    }
  }
}

pub fn lucas_actor(n: Int, k: Int, workers: Int, work_unit: Int) {
  // Start boss
  let assert Ok(boss_started) =
    actor.new(Nil) |> actor.on_message(boss_loop) |> actor.start
  let boss = boss_started.data

  // Start workers
  let worker_subjects = start_n_workers(workers, k)

  // Assign ranges
  assign_ranges(worker_subjects, n, k, work_unit, 1)

  // tell workers to shutdown
  let _ =
    list.map(worker_subjects, fn(r) {
      case r {
        Ok(actor.Started(pid: _, data: subject)) ->
          actor.send(subject, Shutdown)
        _ -> Nil
      }
    })

  // stop boss
  actor.send(boss, WorkerDone)
}

pub fn input_nk() {
  case argv.load().arguments {
    [n, k] ->
      lucas(result.unwrap(int.parse(n), 0), result.unwrap(int.parse(k), 0))
    _ -> io.println("usage: ./lucas n k")
  }
}

pub fn main() {
  input_nk()
}
