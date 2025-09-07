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

type BossMsg {
  ResultFound(Int)
  WorkerDone
}

type WorkerMsg {
  Work(
    range_start: Int,
    range_end: Int,
    current_sum: Int,
    boss: process.Subject(BossMsg),
  )
  Shutdown
}

// worker_do_range: iterate a worker's assigned starts and notify boss for results
fn worker_do_range(
  start: Int,
  finish: Int,
  cur_sum: Int,
  k: Int,
  boss: process.Subject(BossMsg),
) {
  case start <= finish {
    True -> {
      case perfect_square(cur_sum) {
        True -> actor.send(boss, ResultFound(start))
        False -> Nil
      }
      worker_do_range(
        start + 1,
        finish,
        cur_sum - sq(start) + sq(start + k),
        k,
        boss,
      )
    }
    False -> Nil
  }
}

fn worker_loop(
  state: #(Int, process.Subject(BossMsg)),
  msg: WorkerMsg,
) -> actor.Next(#(Int, process.Subject(BossMsg)), WorkerMsg) {
  case state {
    #(k_val, boss_subject) ->
      case msg {
        Work(start, finish, sum, _boss) -> {
          // `state` holds k (window size) and boss subject for worker
          worker_do_range(start, finish, sum, k_val, boss_subject)
          actor.continue(state)
        }

        Shutdown -> {
          // notify boss we're done
          actor.send(boss_subject, WorkerDone)
          actor.stop()
        }
      }
  }
}

// Start a worker actor returning its subject (private)
fn start_worker(
  k: Int,
  boss: process.Subject(BossMsg),
) -> Result(actor.Started(process.Subject(WorkerMsg)), actor.StartError) {
  // initial worker state is a tuple of (k, boss_subject)
  actor.new(#(k, boss))
  |> actor.on_message(worker_loop)
  |> actor.start
}

fn start_n_workers(
  count: Int,
  k: Int,
  boss: process.Subject(BossMsg),
) -> List(Result(actor.Started(process.Subject(WorkerMsg)), actor.StartError)) {
  case count <= 0 {
    True -> []
    False -> [start_worker(k, boss), ..start_n_workers(count - 1, k, boss)]
  }
}

fn boss_loop(
  state: #(List(Int), Int),
  msg: BossMsg,
) -> actor.Next(#(List(Int), Int), BossMsg) {
  case state {
    #(results, remaining) ->
      case msg {
        ResultFound(v) -> actor.continue(#([v, ..results], remaining))

        WorkerDone -> {
          let rem = remaining - 1
          case rem == 0 {
            True -> {
              let sorted = list.sort(results, int.compare)
              list.each(sorted, fn(x) { io.println(int.to_string(x)) })
              actor.stop()
            }
            False -> actor.continue(#(results, rem))
          }
        }
      }
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
  boss: process.Subject(BossMsg),
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
              actor.send(subject, Work(start_idx, e, sum_for_s, boss))
            _ -> Nil
          }
          // rotate: send next ranges using rest ++ [first]
          assign_ranges(
            list.append(rest, [first]),
            n,
            k,
            work_unit,
            e + 1,
            boss,
          )
        }
      }
    }
  }
}

pub fn lucas_actor(n: Int, k: Int, workers: Int, work_unit: Int) {
  // Start boss
  let assert Ok(boss_started) =
    actor.new(#([], workers)) |> actor.on_message(boss_loop) |> actor.start
  let boss = boss_started.data

  // Start workers
  let worker_subjects = start_n_workers(workers, k, boss)

  // Assign ranges (provide boss subject so workers can report back)
  assign_ranges(worker_subjects, n, k, work_unit, 1, boss)

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

  Nil
}

// Sequential collector that emulates worker partitioning and returns results as a list
pub fn lucas_actor_collect(
  n: Int,
  k: Int,
  _workers: Int,
  work_unit: Int,
) -> List(Int) {
  let results = collect_ranges_impl(1, n, k, work_unit, [])
  // return sorted ascending
  list.sort(results, int.compare)
}

// Sequential collector: return sequential lucas results as a list
pub fn lucas_collect(n: Int, k: Int) -> List(Int) {
  list.sort(collect_lucas_impl(1, n, sum_k_squares(k), k, []), int.compare)
}

// Top-level helper used by lucas_collect
fn collect_lucas_impl(
  i: Int,
  n: Int,
  cur_sum: Int,
  k: Int,
  acc: List(Int),
) -> List(Int) {
  case i <= n {
    False -> acc
    True -> {
      let acc2 = case perfect_square(cur_sum) {
        True -> [i, ..acc]
        False -> acc
      }
      collect_lucas_impl(i + 1, n, cur_sum - sq(i) + sq(i + k), k, acc2)
    }
  }
}

// Helper: collect results for a block [s..e]
fn collect_block(
  s: Int,
  e: Int,
  cur_sum: Int,
  k: Int,
  acc: List(Int),
) -> List(Int) {
  case s <= e {
    False -> acc
    True -> {
      let acc2 = case perfect_square(cur_sum) {
        True -> [s, ..acc]
        False -> acc
      }
      collect_block(s + 1, e, cur_sum - sq(s) + sq(s + k), k, acc2)
    }
  }
}

// Helper: iterate ranges sequentially like the actor assigner
fn collect_ranges_impl(
  start_idx: Int,
  n: Int,
  k: Int,
  work_unit: Int,
  acc: List(Int),
) -> List(Int) {
  case start_idx <= n {
    False -> acc
    True -> {
      let e = int.min(n, start_idx + work_unit - 1)
      let sum_for_s =
        sum_k_squares(start_idx + k - 1) - sum_k_squares(start_idx - 1)
      let block_results = collect_block(start_idx, e, sum_for_s, k, [])
      collect_ranges_impl(
        e + 1,
        n,
        k,
        work_unit,
        list.append(acc, block_results),
      )
    }
  }
}

pub fn input_nk() {
  case argv.load().arguments {
    [n, k] ->
      lucas(result.unwrap(int.parse(n), 0), result.unwrap(int.parse(k), 0))

    // Actor mode: lukas N K WORKERS WORK_UNIT
    [n, k, workers, work_unit] -> {
      let n_v = result.unwrap(int.parse(n), 0)
      let k_v = result.unwrap(int.parse(k), 0)
      let w_v = result.unwrap(int.parse(workers), 1)
      let u_v = result.unwrap(int.parse(work_unit), 1)
      lucas_actor(n_v, k_v, w_v, u_v)
    }
    _ -> io.println("usage: ./lucas n k")
  }
}

pub fn main() {
  input_nk()
}
