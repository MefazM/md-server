module BattleStatuses
  PENDING = 1
  READY_TO_START = 2
  IN_PROGRESS = 3
end

module UnitStatuses
  MOVE = 1
  DIE = 3
  START_ATTACK = 4
  FINISH_ATTACK = 5
  DEFAULT = 42
end

module Timings
  ITERATION_TIME = 0.1
  DEFAULT_UNITS_SPAWN_TIME = 5.0
  PING_TIME = 0.5
end
