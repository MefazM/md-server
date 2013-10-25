module BattleStatuses
  PENDING = 1
  READY_TO_START = 2
  IN_PROGRESS = 3
  FINISHED = 4
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

module PlayerStates
  LOGIN = 1
  IN_WORLD = 2
  IN_BATTLE = 3
  READY_TO_FIGHT = 4
end
