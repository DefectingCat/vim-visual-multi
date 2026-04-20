-- lua/visual-multi/test/init_spec.lua
-- Basic tests for visual-multi module loading

local vm = require('visual-multi')
local config = require('visual-multi.config')
local state = require('visual-multi.state')
local offset = require('visual-multi.offset')
local bytes = require('visual-multi.bytes')

local function test_module_loading()
  print("Testing module loading...")

  -- Test init module
  assert(vm ~= nil, "visual-multi.init should load")
  assert(vm.version ~= nil, "version should be defined")

  -- Test config module
  assert(config ~= nil, "visual-multi.config should load")
  assert(config.get ~= nil, "config.get should exist")

  -- Test state module
  assert(state ~= nil, "visual-multi.state should load")
  assert(state.create ~= nil, "state.create should exist")
  assert(state.destroy ~= nil, "state.destroy should exist")
  assert(state.get ~= nil, "state.get should exist")

  -- Test offset module
  assert(offset ~= nil, "visual-multi.offset should load")
  assert(offset.pos2byte ~= nil, "offset.pos2byte should exist")
  assert(offset.byte2pos ~= nil, "offset.byte2pos should exist")

  -- Test bytes module (Python replacement)
  assert(bytes ~= nil, "visual-multi.bytes should load")
  assert(bytes.rebuild_from_map ~= nil, "bytes.rebuild_from_map should exist")
  assert(bytes.lines_with_regions ~= nil, "bytes.lines_with_regions should exist")

  print("[PASS] All modules load correctly")
  return true
end

local function test_bytes_module()
  print("Testing bytes module (Python replacement)...")

  -- Test rebuild_from_map
  local bytes_map = {
    [1] = 1,
    [2] = 1,
    [3] = 1,
    [10] = 1,
    [11] = 1,
    [20] = 1,
  }
  local regions = bytes.rebuild_from_map(bytes_map)
  assert(#regions == 3, "Should create 3 regions from bytes map")
  assert(regions[1][1] == 1 and regions[1][2] == 3, "First region should be [1,3]")
  assert(regions[2][1] == 10 and regions[2][2] == 11, "Second region should be [10,11]")
  assert(regions[3][1] == 20 and regions[3][2] == 20, "Third region should be [20,20]")

  -- Test lines_with_regions
  local test_regions = {
    {l = 1, index = 1},
    {l = 1, index = 2},
    {l = 2, index = 3},
  }
  local lines = bytes.lines_with_regions(test_regions, 0, false)
  assert(lines[1] ~= nil, "Line 1 should have regions")
  assert(#lines[1] == 2, "Line 1 should have 2 regions")
  assert(lines[1][1] == 1 and lines[1][2] == 2, "Line 1 indices should be sorted")

  print("[PASS] bytes module works correctly")
  return true
end

local function run_tests()
  local passed = true

  passed = test_module_loading() and passed
  passed = test_bytes_module() and passed

  if passed then
    print("\n=== All tests passed ===")
  else
    print("\n=== Some tests failed ===")
  end

  return passed
end

return {
  run = run_tests
}