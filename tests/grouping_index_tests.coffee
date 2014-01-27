
Tinytest.add "grouping - index - no index specified", (test) ->
  index = TurkServer._getPartitionedIndex(undefined)

  test.length Object.keys(index), 1
  test.equal index._groupId, 1

Tinytest.add "grouping - index - simple index object", (test) ->
  input = {foo: 1}
  index = TurkServer._getPartitionedIndex(input)

  keyArr = Object.keys(index)
  test.length keyArr, 2
  test.equal keyArr[0], "_groupId"
  test.equal keyArr[1], "foo"
