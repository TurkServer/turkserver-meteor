@Assigners = {}


# Default top level class
class Assigner


# Puts everyone who joins into a single group.
class Assigners.TestAssigner extends Assigner


# Assigns treatments to groups in a randomized, round-robin fashion
class Assigners.RoundRobinAssigner extends Assigner
  constructor: (@treatments) ->


# TODO: separate group from treatment/item assignment
