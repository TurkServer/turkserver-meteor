@Assigners = {}


# Default top level class
class Assigner


# Puts everyone who joins into a default group.
class Assigners.TestAssigner extends Assigner


# Puts people who join into a lobby, which fills fixed size groups when ready.
class Assigners.LobbyAssigner extends Assigner
  constructor: (@groupSize) ->


# TODO: separate lobby from treatment/item assignment
