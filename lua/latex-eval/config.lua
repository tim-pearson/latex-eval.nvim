local M = {}

local function is_list(value)
  if type(value) ~= "table" then
    return false
  end
  if vim.islist then
    return vim.islist(value)
  end
  return vim.tbl_islist(value)
end

local function deep_merge(base, override)
  for key, value in pairs(override or {}) do
    if
      type(value) == "table"
      and type(base[key]) == "table"
      and not is_list(value)
      and not is_list(base[key])
    then
      deep_merge(base[key], value)
    else
      base[key] = vim.deepcopy(value)
    end
  end
  return base
end

M.defaults = {
  keymaps = {
    enabled = true,
    prefix = "<leader>b",
    silent = true,
    mappings = {
      menu = "m",
      evaluate = "e",
      simplify = "s",
      solve = "r",
      define = "d",
      differentiate = "f",
      definitions = "l",
      align = "j",
      health = "h",
    },
    overrides = {},
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
    max_width = 80,
    max_height = 20,
    border = "rounded",
    title_pos = "center",
    close_key = "q",
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
  notifications = {
    enabled = true,
    level = vim.log.levels.INFO,
  },
  menu = {
    border = "rounded",
    title = "latex-eval",
    width = 56,
  },
}

function M.setup(options)
  local base = M.options and vim.deepcopy(M.options)
    or vim.deepcopy(M.defaults)
  local merged = deep_merge(base, options or {})
  local data_path = vim.fn.stdpath("data")
  local state_path = vim.fn.stdpath("state")
  if not state_path or state_path == "" then
    state_path = data_path
  end

  if not merged.python.venv_path or merged.python.venv_path == "" then
    merged.python.venv_path = data_path .. "/latex-eval/venv"
  end
  if
    not merged.definitions.global_path
    or merged.definitions.global_path == ""
  then
    merged.definitions.global_path = state_path
      .. "/latex-eval/definitions.json"
  end

  M.options = merged
  return merged
end

function M.get()
  if not M.options then
    M.setup(nil)
  end
  return M.options
end

function M.reset()
  M.options = nil
end

return M