import gleeunit
import lucas

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn actor_matches_sequential_test_10_3() {
  assert lucas.lucas_collect(10, 3) == lucas.lucas_actor_collect(10, 3, 2, 5)
}

pub fn actor_matches_sequential_test_20_3() {
  assert lucas.lucas_collect(20, 3) == lucas.lucas_actor_collect(20, 3, 2, 5)
}

pub fn actor_matches_sequential_test_40_24() {
  assert lucas.lucas_collect(40, 24) == lucas.lucas_actor_collect(40, 24, 2, 5)
}
