# latex-eval.nvim

`latex-eval.nvim` evaluates, simplifies, solves, differentiates, aligns, and
stores LaTeX math while editing Markdown and LaTeX source.

It is designed to work alongside your existing Markdown rendering setup. It does
not render math and it does not replace `mdmath.nvim` or Kitty. `mdmath.nvim`
remains responsible for rendering; `latex-eval.nvim` only reads and modifies the
underlying Markdown source. When the plugin changes the buffer, an existing
Markdown renderer can update normally.

There is intentionally no custom preview window: `mdmath.nvim` does not currently
render math inside floating windows, so a source-only preview was not kept.

Requires Neovim 0.10 or newer.

---

## Features

- Evaluate expressions numerically or symbolically.
- Simplify expressions with SymPy.
- Solve equations, inferring the variable when unambiguous.
- Differentiate expressions or equation forms.
- Detect math under the cursor or use a visual selection.
- Work in normal mode or visual mode.
- Show results in a floating window and copy them to the clipboard.
- Replace only the mathematical source, preserving Markdown delimiters and the
  surrounding document.
- Store persistent values and user-defined functions.
- Isolated Python environment with pinned dependencies.
- Configurable commands, keymaps, result behavior, and definition paths.
- Optional Treesitter-assisted math detection.
- Join separate `$$` blocks into `align*`, and split them back again.
- Wrap math in `\boxed`, `\underbrace`, `\cancel`, and other commands.
- Edit stored definitions in a Markdown buffer and save with `:w`.

---

## Installation

### lazy.nvim

```lua
return {
  "tim-pearson/latex-eval.nvim",
  config = function()
    require("latex-eval").setup()
  end,
}
```

The plugin also creates its commands and default keymaps automatically if you do
not call `setup()`. Calling `setup()` lets you override configuration.

### Python dependencies

Do not install packages into system Python or a Conda environment. On first use,
`latex-eval.nvim` creates an isolated environment at:

```text
stdpath("data")/latex-eval/venv
```

It prompts before installing. Installation prefers `uv` when available and falls
back to `python3 -m venv` plus pip.

Manual environment commands:

```vim
:LatexEvalInstall
:LatexEvalHealth
```

`latex-eval.nvim` never installs into the host Python environment or the plugin
repository.

If `python3 -m venv` is unavailable on your system, install the OS package for
`venv` (for example `python3-venv` on Debian/Ubuntu) or install `uv`.

---

## Operations

| Operation | Description |
| --- | --- |
| Evaluate | Numerically evaluates an expression when possible; returns symbolic output otherwise. |
| Simplify | Symbolically simplifies with SymPy. |
| Solve | Solves an equation. The target variable is inferred when there is exactly one unknown; otherwise you are prompted. |
| Differentiate | Differentiates with respect to an inferred variable, or an explicitly supplied variable. For equation input, the left-hand side is preserved and the right-hand side is differentiated. |
| Define | Stores a value such as `x=4` or a function such as `f(x)=x^2`. |

Built-in evaluation constants include `c` (speed of light), `e`, `pi`, `i`,
`j`, `oo`, `gamma`, `phi`, and common Unicode aliases. The default `c` value is
applied during numeric evaluation; symbolic simplification keeps `c` symbolic
unless you store your own value for it.

---

## Default keymaps

Defaults use `<leader>b`:

| Key | Action |
| --- | --- |
| `<leader>bm` | Open the action menu |
| `<leader>be` | Evaluate |
| `<leader>bs` | Simplify |
| `<leader>br` | Solve |
| `<leader>bd` | Store definition |
| `<leader>bf` | Differentiate |
| `<leader>bj` | Join/split aligned math |
| `<leader>bw` | Wrap math menu |
| `<leader>bx` | Wrap in `\boxed{...}` |
| `<leader>bu` | Wrap in `\underbrace{...}` |
| `<leader>bo` | Wrap in `\overbrace{...}` |
| `<leader>bc` | Wrap in `\cancel{...}` |
| `<leader>bl` | Open definitions buffer |
| `<leader>bh` | Health check |

Evaluate, simplify, solve, differentiate, define, and join/split work in normal
and visual mode. Menu, definition management, and health check are normal-mode
mappings. Existing mappings are not overwritten; a warning is shown instead.

---

## Commands

| Command | Behavior |
| --- | --- |
| `:LatexEval` | Open the action menu. |
| `:LatexEvalEvaluate [expr]` | Evaluate the argument, or detected math when omitted. |
| `:LatexEvalSimplify [expr]` | Simplify the argument, or detected math. |
| `:LatexEvalSolve [variable]` | Solve detected math, optionally for the given variable. |
| `:LatexEvalDifferentiate [variable]` | Differentiate detected math, optionally for the given variable. |
| `:LatexEvalDefine [expr]` | Store an argument, or detected math. |
| `:LatexEvalDefine global` | Store detected math in global definitions. |
| `:LatexEvalDefine project` | Store detected math in project-local definitions. |
| `:LatexEvalJoinMath` | Join separate `$$` blocks into an `align*` environment. |
| `:LatexEvalSplitMath` | Split an `align`/`gather` environment into separate `$$` blocks. |
| `:LatexEvalToggleAlign` | Toggle between separate blocks and an aligned environment. |
| `:LatexEvalWrap [preset]` | Wrap detected/selected math; opens a menu when no preset is given. |
| `:LatexEvalDefs` | Open an editable Markdown buffer of all definitions. |
| `:LatexEvalInstall` | Install or repair the isolated Python environment. |
| `:LatexEvalHealth` | Report Python version, venv path, dependency versions, imports, and backend status. |

---

## Math detection

In visual mode the selection is used. In normal mode the math surrounding the
cursor is detected.

Supported forms:

```markdown
Inline: $x^2 + 1$

Display: $$x^2 + 1$$

LaTeX delimiters: \(x^2 + 1\) and \[x^2 + 1\]

Environments:
\begin{equation}
x^2 + 1
\end{equation}
```

Supported environments are `equation`, `equation*`, `align`, `align*`, `gather`,
`gather*`, `multline`, and `multline*`. Multiline expressions are supported.

The plugin extracts only the mathematical source. Markdown delimiters are
excluded from the operation and preserved in the buffer. Visual selections that
include delimiters are normalized automatically.

Optional Treesitter detection is enabled by default when a suitable parser is
available. If no math is found, the plugin warns without yanking, changing
registers, or modifying the buffer.

---

## Results and safe replacement

By default, results are shown in a floating window and copied to the `+`
clipboard. When a result exposes a right-hand side, that value is copied
automatically. The source buffer is not modified automatically.

In the result window:

| Key | Action |
| --- | --- |
| `y` | Copy the full displayed result |
| `Y` | Copy only the right-hand side when available |
| `i` | Insert the displayed result after the source line |
| `r` | Replace the source with the full displayed result |
| `R` | Replace only the source right-hand side |
| `a` | Add the full result as a new `$$` math block underneath |
| `q` / `<Esc>` | Close |

The result window also shows a short keybinding help line by default. Disable it
with `results.show_help = false`.

Replacement targets only the expression source range. It preserves:

- `$...$`, `$$...$$`, `\(...\)`, and `\[...\]` delimiters.
- `\begin{...}` / `\end{...}` environment wrappers.
- Indentation before the expression.
- Surrounding prose and other lines.
- Multiline delimiters and environment layout.

For example:

```markdown
The derivative is

$$
f(x) = x^3 + 2x
$$

This concludes the calculation.
```

Differentiating with respect to `x` and pressing `r` changes only the expression:

```markdown
The derivative is

$$
f(x) = 3x^2 + 2
$$

This concludes the calculation.
```

Since this is a normal buffer edit, it is undoable with `u`.

Automatic inline insertion can be enabled:

```lua
require("latex-eval").setup({
  results = {
    inline = true,
    inline_mode = "replace", -- "eol", "below", or "replace"
  },
})
```

---

## Differentiation

Differentiation infers the variable when it is unambiguous. When multiple symbols
are present, use the variable dropdown or pass the variable explicitly:

```vim
:LatexEvalDifferentiate x
```

For equation input, the original left-hand side is kept and the right-hand side is
differentiated:

- `y = 3x` with variable `x` → `y = 3`
- `f(x) = 4x` with variable `x` → `f(x) = 4`
- `y = x^2` with variable `x` → `y = 2 x`

For a plain expression, the result is just the derivative:

- `x^2` → `2 x`

## Aligned math blocks

`:LatexEvalJoinMath`, `:LatexEvalSplitMath`, and `:LatexEvalToggleAlign`
(`<leader>bj`) convert between independent display blocks and one aligned
environment.

Joining:

```markdown
$$
y = 3x
$$

$$
f(x) = x^2
$$
```

becomes:

```markdown
$$
\begin{align*}
y &= 3x \\
f(x) &= x^2
\end{align*}
$$
```

Join inserts `&` before a top-level `=` when the row is not already aligned.
Splitting removes that auto-inserted alignment so plain equations round-trip.
Join requires one expression per `$$` block so the
conversion remains reversible. Surrounding prose is protected: the command
refuses to join or split a mixed region. Visual mode operates on the selected
lines; normal mode operates on the math around the cursor.

## Wrapping math

Use `<leader>bw` or `:LatexEvalWrap` to choose a wrapper. Direct default
keybindings are provided for:

- `\boxed{...}` — `<leader>bx`
- `\underbrace{...}` — `<leader>bu`
- `\overbrace{...}` — `<leader>bo`
- `\cancel{...}` — `<leader>bc`

The menu also includes `\sqrt{...}`, `\text{...}`, `\overline{...}`,
`\underline{...}`, `\hat{...}`, `\bar{...}`, `\vec{...}`, `\tilde{...}`,
`\dot{...}`, `\ddot{...}`, `\mathbf{...}`, `\mathrm{...}`, and
`\operatorname{...}`.

Wrapping replaces only the mathematical source, so surrounding `$`, `$$`,
`\(`/`\)`, `\[`/`\]`, and environment delimiters are preserved.

## Stored definitions

Definitions are stored as JSON.

Global file:

```text
stdpath("state")/latex-eval/definitions.json
```

Optional project file:

```text
.latex-eval.json
```

The project file is searched upward from the current buffer directory. If you
store a project definition and no project file exists, it is created next to the
buffer (or in the current working directory when the buffer has no file path).

Project definitions override global definitions without modifying the global
file.

Example definitions file:

```json
{
  "values": {
    "x": "4",
    "a": "\\frac{1}{2}"
  },
  "functions": {
    "f": {
      "variables": ["x"],
      "expression": "x^2"
    }
  }
}
```

Examples:

1. Store `x=4`, then evaluate `$x+1$` to get `5`.
2. Store `f(x)=x^2`, then evaluate `$f(3)$` to get `9`.
3. With `f(x)=x^2`, evaluate `$f(y)$` to get `y^2`.
4. Multi-argument functions such as `g(x,y)=x*y` are supported.
5. Nested user-function calls are expanded safely without executing Python code.

Definitions are applied to evaluate, simplify, solve, and differentiate.

Manage them with `<leader>bl` or `:LatexEvalDefs`. This opens a Markdown buffer
listing global and project definitions. Edit the lines and write the buffer with
`:w` to save; the JSON files are updated atomically. Existing definitions are
never overwritten by the normal define command without confirmation.

Definitions are parsed as math, never executed as Python.

---

## Configuration

Call `setup()` with any subset of options:

```lua
require("latex-eval").setup({
  keymaps = {
    enabled = true,
    prefix = "<leader>b",
    mappings = {
      menu = "m",
      evaluate = "e",
      simplify = "s",
      solve = "r",
      define = "d",
      differentiate = "f",
      align = "j",
      wrap_menu = "w",
      wrap_boxed = "x",
      wrap_underbrace = "u",
      wrap_overbrace = "o",
      wrap_cancel = "c",
      definitions = "l",
      health = "h",
    },
    overrides = {
      -- evaluate = "<leader>E",
    },
  },
  python = {
    cmd = nil,
    system_python = nil,
    venv_path = nil,
    auto_install = true,
    prompt_install = true,
    request_timeout = 30000,
    install_timeout = 300000,
  },
  results = {
    window = true,
    clipboard = true,
    clipboard_register = "+",
    inline = false,
    inline_mode = "eol",
    actions = true,
    show_help = true,
    max_width = 80,
    max_height = 20,
    border = "rounded",
  },
  definitions = {
    enabled = true,
    global_path = nil,
    project_file = ".latex-eval.json",
    project_search = true,
    default_scope = "global",
    ask_scope = false,
    confirm_overwrite = true,
  },
  selection = {
    treesitter = true,
    fallback_to_line = false,
  },
})
```

Disable a single mapping with `mappings.evaluate = false`, or disable all default
mappings with `keymaps.enabled = false`. Use `keymaps.overrides` for full
left-hand-side overrides.

Set `python.cmd` to use an existing Python executable. Automatic installation is
disabled when `python.cmd` is set; that Python must already have the required
modules installed.

---

## Python environment behavior

- The virtual environment is created outside the repository at
  `stdpath("data")/latex-eval/venv`.
- Dependencies are pinned in `python/requirements.txt`.
- `uv` is preferred when it is on `PATH`.
- Otherwise the plugin uses `python3 -m venv` and pip.
- The first operation prompts before installing when dependencies are missing.
- Installation and requests are asynchronous and do not block Neovim's UI.
- Requests use JSON over stdin/stdout; LaTeX is never passed as a raw command
  line argument.
- Stored expressions are never executed as Python code.
- Backend diagnostics go to stderr; stdout is reserved for JSON responses.

---

## API compatibility

The original public API remains available:

```lua
require("latex-eval").evaluate_visual()
require("latex-eval").evaluate_visual(true) -- simplify
require("latex-eval").solve_visual()
require("latex-eval").diff_visual()
```

New public API:

```lua
require("latex-eval").evaluate()
require("latex-eval").simplify()
require("latex-eval").solve()
require("latex-eval").differentiate()
require("latex-eval").define()
require("latex-eval").wrap("boxed")
require("latex-eval").wrap_menu()
require("latex-eval").toggle_align()
require("latex-eval").join_math()
require("latex-eval").split_math()
require("latex-eval").definitions()
require("latex-eval").menu()
require("latex-eval").health()
require("latex-eval").install()
```

Each new operation can also receive options such as an explicit selection:

```lua
require("latex-eval").evaluate({
  selection = { text = "1+1", kind = "argument" },
})
```

---

## Extending

Add a Python operation:

1. Create `python/latex_eval/operations/<name>.py` with `NAME` and `run(request, engine)`.
2. Register it in `python/latex_eval/operations/__init__.py`.

Add a Lua feature:

1. Create `lua/latex-eval/features/<name>.lua` with `run(selection, options)`.
2. Register it in `lua/latex-eval/features/init.lua`.

---

## Development and tests

Python tests do not require Neovim:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r python/requirements.txt pytest
pytest tests/python
```

Lua files can be syntax-checked with any Lua parser supported by your toolchain.

---

## Troubleshooting

**`:LatexEvalHealth` reports missing Python environment**

Run `:LatexEvalInstall`. If virtual environment creation fails, install
`python3-venv` or `uv`.

**No math detected**

Place the cursor inside the math, or select the math first. Ensure delimiters are
balanced. Enable `selection.fallback_to_line` if you want to operate on the
current non-empty line when no math block is found.

**A solve or differentiate command asks for a variable**

The expression contains more than one unknown symbol. Choose the target, or use
`:LatexEvalSolve x` / `:LatexEvalDifferentiate x`.

**A definition does not take effect**

Check `:LatexEvalDefs`. Project definitions override global definitions. Invalid
JSON files are reported and are not overwritten.

**Replacement removed spacing or delimiters**

The `r` action replaces only the expression source range. It preserves math
delimiters, environment wrappers, indentation, and surrounding prose. If you
selected a custom range, select only the expression source for the most
predictable result.

**Markdown rendering did not update**

`latex-eval.nvim` edits the Markdown buffer directly. Your existing renderer
should update when the buffer changes. The plugin does not create a separate
document or rendering pipeline.