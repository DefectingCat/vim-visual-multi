<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# test/tests/

## Test Structure
Each test subdirectory contains exactly three files:

| File | Description |
|------|-------------|
| `commands.py` | Python script calling `keys()` to simulate keystrokes |
| `input_file.txt` | Initial buffer content before test |
| `expected_output_file.txt` | Expected buffer content after commands execute |

## Subdirectories

| Directory | Feature Tested | Description |
|-----------|----------------|-------------|
| `abbrev/` | Abbreviations | Insert mode abbreviations with `:VMLive` and replace mode |
| `alignment/` | Alignment | Alignment feature via `\\\\A` and `\\\\a` commands |
| `backspace/` | Backspace | Backspace operations with multibyte characters |
| `change/` | Change Commands | Various change operations: `I`, `gciw`, `ciw`, `c$`, `cc`, `cl`, `C` |
| `change2/` | Change Commands #2 | Change inside brackets `gcib`, tab cycling, `c2aw` |
| `cquote/` | Quote Operations | Change inside/around double quotes: `ci"`, `ca"` |
| `curs2/` | Cursor Operations #2 | Operations at cursors: `D`, `C`, regex find, `s`, `c2E` |
| `curs_del/` | Cursor Delete | Delete operations at cursors: `dW`, `d2l`, `d4h`, paste |
| `dot/` | Dot/Select Operator | Dot repeat, select inside quote `si'` |
| `example/` | Basic Example | Simple cursor down and insert: `\<C-Down>`, `i` |
| `example2/` | Basic Example #2 | Basic multi-cursor change with `\<C-n>` and `C` |
| `getcc/` | Insert Operations | Insert carriage return, insert line above with `O` |
| `oO/` | Replace Mode | Replace mode `R` with multibyte chars and backspace |
| `pasteatcur/` | Paste at Cursor | Paste at cursor position after visual block yank |
| `regex/` | Regex/Find/Select All | Regex search `\\\\/`, find operator `\\\\f`, select all `\\\\A` |
| `repl/` | Transpositions | Transpositions and region splitting with `\\\\t`, `\\\\s` |
| `trans/` | Paste Operations | Paste at cursor after visual-select change |
| `vmsearch/` | VMSearch | `:VMSearch` and `:%VMSearch` commands |

## For AI Agents

### Running Specific Tests
```bash
# Run single test
./test.py abbrev

# Run with diff output on failure
./test.py -d change

# Run in Neovim
./test.py -n regex
```

### Creating New Tests
1. Create directory: `mkdir test/tests/[test_name]`
2. Create `input_file.txt` with initial buffer content
3. Create `commands.py` with keystrokes via `keys()` calls
4. Create `expected_output_file.txt` with expected result
5. Run test to verify: `./test.py [test_name]`

### commands.py Format
```python
# Comment describing the test
L = '\\\\\\\\'  # Shorthand for plugin leader (4 backslashes)

keys(r':set tw=79\<CR>')  # Raw string for escape sequences
keys('2\<C-Down>')        # Select 2 lines down
keys('c')                 # Change command
keys('new_text')          # Type text
keys(r'\<Esc>')           # Escape
keys(r'\<Esc>')           # Exit multicursor mode
```

### Escape Sequences in commands.py
| Notation | Meaning |
|----------|---------|
| `r'\<CR>'` | Carriage return (Enter) |
| `r'\<Esc>'` | Escape key |
| `r'\<C-N>'` | Ctrl-N (add cursor down) |
| `r'\<C-Down>'` | Ctrl-Down (add cursor on line below) |
| `r'\<Tab>'` | Tab key |
| `r'\<BS>'` | Backspace |
| `r'\<Space>'` | Space character |
| `'\\\\\\\\'` | Plugin leader (4 backslashes for Python escaping) |

### Common Test Patterns
- Add cursors: `keys(r'3\<C-Down>')` — 3 cursors below
- Change text: `keys('c')` then `keys('text')` then `keys(r'\<Esc>')`
- Exit multicursor: Two escapes — one exits insert, one exits multicursor mode
- Plugin commands: Use `L = '\\\\\\\\'` then `keys(L + 'A')` for select all

<!-- MANUAL: -->
