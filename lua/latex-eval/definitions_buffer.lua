local M = {}

local BUFFER_NAME = "latex-eval://definitions"
local active_buffer = nil
local SECTION_PATTERN = "^%s*<!%-%-%s*latex%-eval:(%w+):(%w+)%s*%-%->%s*$"

local function config()
  return require("latex-eval.config").get()
end

local function store()
  return require("latex-eval.store")
end

local function ui()
  return require("latex-eval.ui")
end

local function trim(value)
  return vim.trim(value or "")
end

local function empty_scope()
  return { values = {}, functions = {} }
end

local function sorted_keys(value)
  local keys = {}
  for key in pairs(value or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function function_line(name, definition)
  return string.format(
    "%s(%s) = %s",
    name,
    table.concat(definition.variables or {}, ", "),
    definition.expression
  )
end

function M.render(global, project, project_path)
  local lines = {
    "# latex-eval definitions",
    "",
    "Edit definitions below, then write this buffer with `:w`.",
    "One definition per line: `x = 4` or `f(x) = x^2`.",
    "",
    "<!-- latex-eval:global:values -->",
    "## Global values",
    "",
  }

  for _, name in ipairs(sorted_keys(global.values)) do
    lines[#lines + 1] = name .. " = " .. global.values[name]
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "<!-- latex-eval:global:functions -->"
  lines[#lines + 1] = "## Global functions"
  lines[#lines + 1] = ""
  for _, name in ipairs(sorted_keys(global.functions)) do
    lines[#lines + 1] = function_line(name, global.functions[name])
  end

  if project_path and project_path ~= "" then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "<!-- latex-eval:project:values -->"
    lines[#lines + 1] = "## Project values"
    lines[#lines + 1] = ""
    for _, name in ipairs(sorted_keys(project.values)) do
      lines[#lines + 1] = name .. " = " .. project.values[name]
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "<!-- latex-eval:project:functions -->"
    lines[#lines + 1] = "## Project functions"
    lines[#lines + 1] = ""
    for _, name in ipairs(sorted_keys(project.functions)) do
      lines[#lines + 1] = function_line(name, project.functions[name])
    end
  end

  return lines
end

local function split_variables(value)
  local variables = {}
  for raw_variable in (value or ""):gmatch("[^,]+") do
    local variable = trim(raw_variable)
    if variable ~= "" then
      if not variable:match("^[%a_][%w_]*$") then
        return nil
      end
      variables[#variables + 1] = variable
    end
  end
  return variables
end

local function parse_line(line, kind)
  local value = trim(line)
  if value == "" or value:sub(1, 1) == "#" then
    return nil
  end
  if value:sub(1, 4) == "<!--" then
    return nil
  end
  value = value:gsub("^%-%s+", "")
  value = require("latex-eval.selection").strip_math_delimiters(value)

  if kind == "functions" then
    local name, arguments, expression =
      value:match("^([%a_][%w_]*)%s*%((.-)%)%s*=%s*(.+)$")
    if not name then
      return nil, "Invalid function definition: " .. value
    end
    local variables = split_variables(arguments)
    if not variables then
      return nil, "Invalid function parameters: " .. value
    end
    return {
      kind = "function",
      name = name,
      variables = variables,
      expression = trim(expression),
    }
  end

  local name, expression = value:match("^([%a_][%w_]*)%s*=%s*(.+)$")
  if not name then
    return nil, "Invalid value definition: " .. value
  end
  return {
    kind = "value",
    name = name,
    expression = trim(expression),
  }
end

function M.parse(lines)
  local result = {
    global = empty_scope(),
    project = empty_scope(),
  }
  local scope = nil
  local kind = nil
  local found_section = false

  for index, line in ipairs(lines) do
    local marker_scope, marker_kind = line:match(SECTION_PATTERN)
    if marker_scope then
      if marker_scope ~= "global" and marker_scope ~= "project" then
        return nil, "Unknown definition scope on line " .. index
      end
      if marker_kind ~= "values" and marker_kind ~= "functions" then
        return nil, "Unknown definition section on line " .. index
      end
      scope = marker_scope
      kind = marker_kind
      found_section = true
    elseif scope and kind then
      local definition, error_message = parse_line(line, kind)
      if error_message then
        return nil, error_message .. " (line " .. index .. ")"
      end
      if definition then
        local target = result[scope]
        local bucket = kind == "values" and target.values or target.functions
        if bucket[definition.name] ~= nil then
          return nil, "Duplicate definition '"
            .. definition.name
            .. "' (line "
            .. index
            .. ")"
        end
        if definition.kind == "value" then
          bucket[definition.name] = definition.expression
        else
          bucket[definition.name] = {
            variables = definition.variables,
            expression = definition.expression,
          }
        end
      end
    end
  end

  if not found_section then
    return nil, "No latex-eval definition sections were found"
  end
  return result
end

local function write_scope(path, scope)
  local data = store().empty()
  for name, value in pairs(scope.values) do
    data.values[name] = value
  end
  for name, definition in pairs(scope.functions) do
    data.functions[name] = definition
  end
  return store().write(path, data)
end

function M.save(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local definitions, error_message = M.parse(lines)
  if not definitions then
    ui().error(error_message)
    return
  end

  local project_path = vim.b[bufnr].latex_eval_project_path
  local project_count = 0
  for _ in pairs(definitions.project.values) do
    project_count = project_count + 1
  end
  for _ in pairs(definitions.project.functions) do
    project_count = project_count + 1
  end
  if project_count > 0 and not project_path then
    ui().error("Project-local definitions are not configured")
    return
  end

  local global_path = store().global_path()
  local global_ok, global_error = write_scope(global_path, definitions.global)
  if not global_ok then
    ui().error("Could not save global definitions: " .. tostring(global_error))
    return
  end

  if project_count > 0 or (project_path and vim.fn.filereadable(project_path) == 1) then
    local project_ok, project_error =
      write_scope(project_path, definitions.project)
    if not project_ok then
      ui().error(
        "Could not save project definitions: " .. tostring(project_error)
      )
      return
    end
  end

  vim.bo[bufnr].modified = false
  ui().info("Saved latex-eval definitions")
end

function M.open()
  if active_buffer and vim.api.nvim_buf_is_valid(active_buffer) then
    vim.api.nvim_win_set_buf(0, active_buffer)
    return
  end

  local global, global_error = store().load_global()
  if not global then
    ui().error("Could not read global definitions: " .. tostring(global_error))
    return
  end
  global = global or empty_scope()

  local project = empty_scope()
  local project_path = store().project_write_path()
  if project_path then
    local loaded, project_error = store().read(project_path)
    if loaded == nil then
      ui().error(
        "Could not read project definitions: " .. tostring(project_error)
      )
      return
    end
    project = loaded
  end

  local buffer = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buffer, BUFFER_NAME)
  vim.api.nvim_buf_set_lines(
    buffer,
    0,
    -1,
    false,
    M.render(global, project, project_path)
  )

  vim.bo[buffer].buftype = "acwrite"
  vim.bo[buffer].bufhidden = "hide"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].modifiable = true
  vim.bo[buffer].filetype = "markdown"
  vim.bo[buffer].modified = false
  vim.b[buffer].latex_eval_project_path = project_path

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buffer,
    callback = function()
      M.save(buffer)
    end,
  })

  active_buffer = buffer
  vim.api.nvim_win_set_buf(0, buffer)
end

return M