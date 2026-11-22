local M = {}

local warned_paths = {}

local function config()
  return require("latex-eval.config").get()
end

local function ui()
  return require("latex-eval.ui")
end

local function empty_object()
  if vim.empty_dict then
    return vim.empty_dict()
  end
  return {}
end

local function empty()
  return { values = empty_object(), functions = empty_object() }
end

local function normalize(data)
  if type(data) ~= "table" then
    return nil, "Definitions file must contain a JSON object"
  end

  local result = empty()
  if type(data.values) == "table" then
    for name, value in pairs(data.values) do
      if type(name) == "string" and name ~= "" then
        if type(value) == "string" then
          result.values[name] = value
        elseif type(value) == "number" then
          result.values[name] = tostring(value)
        end
      end
    end
  end
  if type(data.functions) == "table" then
    for name, definition in pairs(data.functions) do
      if
        type(name) == "string"
        and name ~= ""
        and type(definition) == "table"
        and type(definition.variables) == "table"
        and type(definition.expression) == "string"
      then
        local variables = {}
        for _, variable in ipairs(definition.variables) do
          if type(variable) == "string" then
            variables[#variables + 1] = variable
          end
        end
        result.functions[name] = {
          variables = variables,
          expression = definition.expression,
        }
      end
    end
  end
  return result
end

local function warn_once(path, message)
  if warned_paths[path] then
    return
  end
  warned_paths[path] = true
  ui().warn("Could not read " .. path .. ": " .. message)
end

function M.empty()
  return empty()
end

function M.global_path()
  return config().definitions.global_path
end

function M.project_path()
  local settings = config().definitions
  if settings.project_path then
    return settings.project_path
  end
  if not settings.project_search or not settings.project_file then
    return nil
  end
  if settings.project_file == "" then
    return nil
  end

  local start = vim.fn.expand("%:p:h")
  if not start or start == "" then
    start = vim.fn.getcwd()
  end
  local found = vim.fs.find(settings.project_file, {
    upward = true,
    path = start,
    type = "file",
  })
  if found and found[1] then
    return found[1]
  end
  return nil
end

function M.project_write_path()
  local settings = config().definitions
  local existing = M.project_path()
  if existing then
    return existing
  end
  if not settings.project_file or settings.project_file == "" then
    return nil
  end
  local directory = vim.fn.expand("%:p:h")
  if not directory or directory == "" then
    directory = vim.fn.getcwd()
  end
  return vim.fs.joinpath(directory, settings.project_file)
end

function M.read(path)
  if not path or path == "" then
    return empty()
  end
  if vim.fn.filereadable(path) ~= 1 then
    return empty()
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, tostring(lines)
  end
  local content = table.concat(lines, "\n")
  if vim.trim(content) == "" then
    return empty()
  end

  local decoded_ok, decoded = pcall(vim.json.decode, content)
  if not decoded_ok then
    return nil, tostring(decoded)
  end
  return normalize(decoded)
end

function M.write(path, data)
  if not path or path == "" then
    return false, "No definitions path is configured"
  end

  local directory = vim.fn.fnamemodify(path, ":h")
  local directory_ok = pcall(vim.fn.mkdir, directory, "p")
  if not directory_ok then
    return false, "Could not create directory " .. directory
  end

  local encoded_ok, encoded = pcall(vim.json.encode, data)
  if not encoded_ok then
    return false, tostring(encoded)
  end

  local temporary = path
    .. ".tmp."
    .. tostring(vim.fn.getpid())
    .. "."
    .. tostring(os.time())
  local write_ok, write_error = pcall(vim.fn.writefile, { encoded }, temporary)
  if not write_ok then
    return false, tostring(write_error)
  end

  local uv = vim.uv or vim.loop
  if uv and uv.fs_rename then
    local renamed, rename_error = uv.fs_rename(temporary, path)
    if renamed then
      return true
    end
    pcall(os.remove, temporary)
    return false, tostring(rename_error)
  end

  local fallback_ok, fallback_error =
    pcall(vim.fn.writefile, { encoded }, path)
  pcall(os.remove, temporary)
  if not fallback_ok then
    return false, tostring(fallback_error)
  end
  return true
end

function M.load_global()
  return M.read(M.global_path())
end

function M.load_project()
  return M.read(M.project_path())
end

function M.collect()
  local merged = empty()
  local global, global_error = M.load_global()
  if not global then
    warn_once(M.global_path(), global_error)
    global = empty()
  end
  for name, value in pairs(global.values) do
    merged.values[name] = value
  end
  for name, definition in pairs(global.functions) do
    merged.functions[name] = definition
  end

  local project_path = M.project_path()
  if project_path then
    local project, project_error = M.read(project_path)
    if not project then
      warn_once(project_path, project_error)
      project = empty()
    end
    for name, value in pairs(project.values) do
      merged.values[name] = value
    end
    for name, definition in pairs(project.functions) do
      merged.functions[name] = definition
    end
  end

  return merged
end

function M.list()
  local entries = {}
  local function add(scope, data)
    if not data then
      return
    end
    for name, value in pairs(data.values) do
      entries[#entries + 1] = {
        kind = "value",
        name = name,
        value = value,
        scope = scope,
      }
    end
    for name, definition in pairs(data.functions) do
      entries[#entries + 1] = {
        kind = "function",
        name = name,
        variables = definition.variables,
        expression = definition.expression,
        scope = scope,
      }
    end
  end

  local global = M.load_global()
  add("global", global)
  local project_path = M.project_path()
  if project_path then
    add("project", M.load_project())
  end

  table.sort(entries, function(left, right)
    if left.scope ~= right.scope then
      return left.scope < right.scope
    end
    if left.kind ~= right.kind then
      return left.kind < right.kind
    end
    return left.name < right.name
  end)
  return entries
end

function M.exists(kind, name, scope)
  local path = scope == "project" and M.project_write_path() or M.global_path()
  local data, error_message = M.read(path)
  if not data then
    return false, error_message
  end
  if kind == "value" then
    return data.values[name] ~= nil
  end
  return data.functions[name] ~= nil
end

function M.save(definition, scope, callback)
  callback = callback or function() end
  if type(definition) ~= "table" or not definition.name then
    callback(false, "Invalid definition")
    return
  end

  scope = scope == "project" and "project" or "global"
  local path = scope == "project" and M.project_write_path() or M.global_path()
  if not path then
    callback(false, "Project-local definitions are not configured")
    return
  end

  local data, read_error = M.read(path)
  if not data then
    ui().error("Refusing to overwrite malformed definitions: " .. read_error)
    callback(false, read_error)
    return
  end

  local exists = definition.kind == "value"
      and data.values[definition.name] ~= nil
    or definition.kind == "function"
      and data.functions[definition.name] ~= nil

  local function persist()
    if definition.kind == "value" then
      data.values[definition.name] = definition.expression
      data.functions[definition.name] = nil
    else
      data.functions[definition.name] = {
        variables = definition.variables or {},
        expression = definition.expression,
      }
      data.values[definition.name] = nil
    end

    local ok, write_error = M.write(path, data)
    if not ok then
      ui().error("Could not save definition: " .. write_error)
      callback(false, write_error)
      return
    end
    callback(true)
  end

  if exists and config().definitions.confirm_overwrite then
    ui().confirm(
      "Overwrite existing "
        .. definition.kind
        .. " '"
        .. definition.name
        .. "' in "
        .. scope
        .. " definitions?",
      function(confirmed)
        if confirmed then
          persist()
        else
          callback(false, "cancelled")
        end
      end
    )
    return
  end

  persist()
end

function M.delete(kind, name, scope, callback)
  callback = callback or function() end
  local path = scope == "project" and M.project_write_path() or M.global_path()
  local data, read_error = M.read(path)
  if not data then
    ui().error("Could not read definitions: " .. tostring(read_error))
    callback(false, read_error)
    return
  end

  local exists = kind == "value" and data.values[name] ~= nil
    or kind == "function" and data.functions[name] ~= nil
  if not exists then
    callback(false, "Definition not found")
    return
  end

  ui().confirm(
    "Delete " .. kind .. " '" .. name .. "' from " .. scope .. " definitions?",
    function(confirmed)
      if not confirmed then
        callback(false, "cancelled")
        return
      end
      if kind == "value" then
        data.values[name] = nil
      else
        data.functions[name] = nil
      end
      local ok, write_error = M.write(path, data)
      if not ok then
        ui().error("Could not delete definition: " .. write_error)
        callback(false, write_error)
        return
      end
      callback(true)
    end
  )
end

return M