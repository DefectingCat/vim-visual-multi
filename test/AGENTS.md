<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# test/

## Key Files

| File | Description |
|------|-------------|
| `test.py` | Main test runner script |
| `README.md` | Test documentation and instructions |
| `requirements.txt` | Python dependencies (vimrunner, pynvim) |
| `run_lua_tests.sh` | Lua test runner for Neovim tests |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `default/` | Default vimrc.vim configuration for tests |
| `tests/` | Individual test cases (16 tests) |

## For AI Agents

### Running Tests
```bash
# Run all tests
./test.py

# Run specific test
./test.py [test_name]

# List all tests
./test.py -l

# Run with custom key interval (default 0.1s)
./test.py -t 0.3

# Show diff for failed tests
./test.py -d

# Run in Neovim instead of Vim
./test.py -n

# Run with live editing disabled
./test.py -L
```

### Test Structure
Each test in `tests/[name]/` contains:
- `input_file.txt` — Initial buffer content
- `commands.py` — Keystrokes to execute via `keys()` function
- `expected_output_file.txt` — Expected buffer after commands
- `vimrc.vim` (optional) — Custom vimrc for this test
- `config.json` (optional) — Constraints like `max_cpu_time`

### Creating New Tests
1. Create directory in `tests/[test_name]/`
2. Add required files: `input_file.txt`, `commands.py`, `expected_output_file.txt`
3. In `commands.py`, escape special characters:
   - Literal backslash: `r'\\'`
   - Literal double quote: `r'\"'`
   - Key notation: `r'\<CR>'`

Alternative: Call `:call vm#special#commands#new_test()` from Vim.

### Dependencies
- Python 3 with vimrunner and pynvim packages
- Vim 8+ or Neovim for running tests
- Tests compare generated output against expected output using file comparison

<!-- MANUAL: -->
