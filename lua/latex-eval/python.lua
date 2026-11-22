local M = {}

local VERSION_SCRIPT = [[import json, sys, importlib.metadata as metadata
data = {"python": sys.version.split()[0]}
for name in ("sympy", "latex2sympy2", "antlr4-python3-runtime"):
    try:
        data[name] = metadata.version(name)
    except Exception:
        data[name] = None
import sympy
import latex2sympy2
print(json.dumps(data))
]]

local function config()
  return require("latex-eval.config").get()
end

local function notify()
  return require("latex-eval.ui")
end

local function trim(value)
  return vim.trim(value or "")
end

local function first_line(value)
  local text = trim(value)
  local line = text:match("^([^\n]+)")
  return line or text
end

local function executable(path)
  return path and path ~= "" and vim.fn.executable(path) == 1
end

function M.plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  local lua_directory = vim.fn.fnamemodify(source, ":h")
  return vim.fn.fnamemodify(lua_directory, ":h:h")
end

function M.backend_script()
  return M.plugin_root() .. "/python/main.py"
end

function M.requirements_path()
  return M.plugin_root() .. "/python/requirements.txt"
end

function M.system_python()
  local configured = config().python.system_python
  if configured and configured ~= "" then
    return configured
  end
  for _, candidate in ipairs({ "python3", "python", "py" }) do
    if executable(candidate) then
      return candidate
    end
  end
  return nil
end

function M.venv_python()
  local path = config().python.venv_path
  if vim.fn.has("win32") == 1 then
    return path .. "/Scripts/python.exe"
  end
  return path .. "/bin/python"
end

function M.python_bin()
  local configured = config().python.cmd
  if configured and configured ~= "" then
    return configured
  end
  return M.venv_python()
end

function M.venv_ready()
  return executable(M.venv_python())
end

function M.spawn(command, options, callback)
  options = options or {}
  if not vim.system then
    callback({
      code = -1,
      stdout = "",
      stderr = "vim.system is unavailable; Neovim 0.10 or newer is required",
    })
    return
  end

  local process_options = {
    text = options.text ~= false,
    timeout = options.timeout,
    stdin = options.stdin,
  }
  local ok, result = pcall(
    vim.system,
    command,
    process_options,
    function(object)
      vim.schedule(function()
        callback(object)
      end)
    end
  )
  if not ok then
    callback({ code = -1, stdout = "", stderr = tostring(result) })
  end
end

function M.check_dependencies(callback, options)
  options = options or {}
  if M._dep_ok and not options.force then
    callback(true)
    return
  end

  local binary = M.python_bin()
  if not executable(binary) then
    callback(false, "Python executable not found: " .. binary)
    return
  end

  M.spawn({
    binary,
    "-c",
    "import sympy, latex2sympy2",
  }, { timeout = 30000 }, function(object)
    if object.code == 0 then
      M._dep_ok = true
      callback(true)
      return
    end
    M._dep_ok = false
    callback(
      false,
      "Python dependencies are missing: " .. first_line(object.stderr)
    )
  end)
end

local function run_commands(commands, index, finish)
  if index > #commands then
    finish(true)
    return
  end

  M.spawn(commands[index], {
    timeout = config().python.install_timeout,
  }, function(object)
    if object.code ~= 0 then
      local message = first_line(object.stderr)
      if message == "" then
        message = first_line(object.stdout)
      end
      finish(
        false,
        "Installation command failed: "
          .. table.concat(commands[index], " ")
          .. (message ~= "" and (": " .. message) or "")
      )
      return
    end
    run_commands(commands, index + 1, finish)
  end)
end

function M.install(callback, options)
  callback = callback or function() end
  options = options or {}

  if M._installing then
    M._install_waiters = M._install_waiters or {}
    table.insert(M._install_waiters, callback)
    return
  end

  M._installing = true
  M._install_waiters = { callback }

  local function finish(ok, message)
    M._installing = false
    M._dep_ok = nil
    local waiters = M._install_waiters or {}
    M._install_waiters = {}
    for _, waiter in ipairs(waiters) do
      waiter(ok, message)
    end
  end

  local settings = config().python
  if settings.cmd and settings.cmd ~= "" then
    finish(
      false,
      "Automatic installation is disabled when python.cmd is configured"
    )
    return
  end

  local uv = executable("uv") and "uv" or nil
  local system_python = M.system_python()
  local venv_python = M.venv_python()
  local venv_ready = M.venv_ready()
  local commands = {}

  if uv then
    if not venv_ready then
      commands[#commands + 1] = { uv, "venv", settings.venv_path }
    end
    commands[#commands + 1] = {
      uv,
      "pip",
      "install",
      "--python",
      venv_python,
      "-r",
      M.requirements_path(),
    }
  else
    if not system_python then
      finish(
        false,
        "No system python3 found and uv is not available. Install uv or python3-venv."
      )
      return
    end
    if not venv_ready then
      commands[#commands + 1] = {
        system_python,
        "-m",
        "venv",
        settings.venv_path,
      }
    end
    commands[#commands + 1] = {
      venv_python,
      "-m",
      "pip",
      "install",
      "-r",
      M.requirements_path(),
    }
  end

  notify().info("Installing isolated Python dependencies for latex-eval...")
  run_commands(commands, 1, function(ok, message)
    if not ok then
      notify().error(message)
      finish(false, message)
      return
    end
    M._dep_ok = nil
    M.check_dependencies(function(dependencies_ok, dependency_message)
      if dependencies_ok then
        notify().info("latex-eval Python environment is ready")
        finish(true)
      else
        notify().error(dependency_message)
        finish(false, dependency_message)
      end
    end, { force = true })
  end)
end

function M._maybe_install(callback, reason)
  local settings = config().python
  if settings.cmd and settings.cmd ~= "" then
    callback(
      false,
      reason
        .. ". Install the requirements manually for the configured python.cmd."
    )
    return
  end
  if not settings.auto_install then
    callback(
      false,
      (reason or "Python environment is not ready")
        .. ". Run :LatexEvalInstall to install it."
    )
    return
  end
  if not settings.prompt_install then
    M.install(callback)
    return
  end

  vim.ui.select({ "Install now", "Cancel" }, {
    prompt = (reason or "Python dependencies are missing")
      .. ". Install the isolated environment now?",
  }, function(choice)
    if choice == "Install now" then
      M.install(callback)
    else
      callback(false, "Automatic installation was cancelled")
    end
  end)
end

function M.ensure(callback)
  local binary = M.python_bin()
  if not executable(binary) then
    M._maybe_install(callback, "Python environment not found at " .. binary)
    return
  end

  M.check_dependencies(function(ok, message)
    if ok then
      callback(true)
    else
      M._maybe_install(callback, message)
    end
  end)
end

function M.health(callback)
  callback = callback or function() end
  local settings = config()
  local lines = {
    "latex-eval health",
    "venv path: " .. tostring(settings.python.venv_path),
    "python executable: " .. tostring(M.python_bin()),
    "system python: " .. tostring(M.system_python() or "not found"),
    "uv: " .. (executable("uv") and "available" or "not found"),
  }

  local binary = M.python_bin()
  if not executable(binary) then
    lines[#lines + 1] = "status: Python environment is not installed"
    callback(lines, false)
    return
  end

  M.spawn({ binary, "--version" }, { timeout = 15000 }, function(version)
    lines[#lines + 1] = "version: "
      .. (trim(version.stdout) ~= "" and trim(version.stdout)
        or trim(version.stderr))

    M.spawn({ binary, "-c", VERSION_SCRIPT }, { timeout = 30000 }, function(deps)
      if deps.code == 0 then
        local ok, data = pcall(vim.json.decode, deps.stdout)
        if ok and type(data) == "table" then
          lines[#lines + 1] = "sympy: "
            .. tostring(data["sympy"] or "missing")
          lines[#lines + 1] = "latex2sympy2: "
            .. tostring(data["latex2sympy2"] or "missing")
          lines[#lines + 1] = "antlr4 runtime: "
            .. tostring(data["antlr4-python3-runtime"] or "missing")
        end
        lines[#lines + 1] = "imports: ok"
      else
        lines[#lines + 1] = "imports: failed ("
          .. first_line(deps.stderr)
          .. ")"
      end

      local runner = require("latex-eval.runner")
      runner.run({ operation = "ping" }, function(error, response)
        if error then
          lines[#lines + 1] = "backend: failed ("
            .. tostring(error.message or error)
            .. ")"
          callback(lines, false)
        else
          lines[#lines + 1] = "backend: ok ("
            .. tostring(response.result or "pong")
            .. ")"
          callback(lines, true)
        end
      end, { skip_ensure = true })
    end)
  end)
end

return M