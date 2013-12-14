module UnitStatuses
  # MOVE = 1
  # DIE = 3
  # ATTACK = 4
  # DEFAULT = 42

  MOVE = 1
  DIE = 3
  ATTACK_MELEE = 4
  ATTACK_RANGE = 5
  IDLE = 42

end

module Timings
  ITERATION_TIME = 0.1
  DEFAULT_UNITS_SPAWN_TIME = 5.0
  PING_TIME = 0.5
  DEFERRED_TASKS_PROCESS_TIME = 0.1
end

module PlayerStates
  LOGIN = 1
  IN_WORLD = 2
  IN_BATTLE = 3
  READY_TO_FIGHT = 4
end
