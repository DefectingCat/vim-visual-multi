-- lua/visual-multi/test/run_tests.lua
-- Test runner for all VM Lua tests

local M = {}

function M.run_all()
  print("\n" .. string.rep("=", 60))
  print("Visual Multi Lua Test Suite")
  print(string.rep("=", 60))

  local all_passed = true
  local total_pass = 0
  local total_fail = 0

  -- List of test modules to run
  local test_modules = {
    { name = "Init", path = "visual-multi.test.init_spec" },
    { name = "Region", path = "visual-multi.test.region_spec" },
    { name = "Global", path = "visual-multi.test.global_spec" },
    { name = "Phase 3", path = "visual-multi.test.phase3_spec" },
    { name = "Phase 4", path = "visual-multi.test.phase4_spec" },
    { name = "Phase 5", path = "visual-multi.test.phase5_spec" },
  }

  for _, test in ipairs(test_modules) do
    print("\n" .. string.rep("-", 40))
    print("Running " .. test.name .. " tests...")
    print(string.rep("-", 40))

    local ok, module = pcall(require, test.path)
    if ok and module and module.run_all then
      local passed = module.run_all()
      total_pass = total_pass + (module.pass_count or 0)
      total_fail = total_fail + (module.fail_count or 0)
      if not passed then
        all_passed = false
      end
    else
      print("[ERROR] Failed to load test module: " .. test.path)
      total_fail = total_fail + 1
      all_passed = false
    end
  end

  print("\n" .. string.rep("=", 60))
  print("TOTAL RESULTS")
  print(string.rep("=", 60))
  print("Total Passed: " .. total_pass)
  print("Total Failed: " .. total_fail)
  print(string.rep("=", 60))

  if all_passed then
    print("\n✓ ALL TESTS PASSED")
  else
    print("\n✗ SOME TESTS FAILED")
  end

  return all_passed
end

-- Run tests if executed directly
if vim and vim.api then
  M.run_all()
end

return M
