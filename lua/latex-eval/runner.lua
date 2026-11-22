local M = {}

local function config()
  return require("latex-eval.config").get()
end

local function python()
  return require("latex-eval.python")
end

local function store()
  return require("latex-eval.store")
end

local function decode_response(stdout)
  local raw = vim.trim(stdout or "")
  if raw == "" then
    return nil, "Backend returned an empty response"
  end

  local ok, response = pcall(vim.json.decode, raw)
  if ok and type(response) == "table" then
    return response
  end

  local lines = vim.split(raw, "\n", { plain = true })
  local last = lines[#lines]
  if last and last ~= raw then
    local fallback_ok, fallback = pcall(vim.json.decode, last)
    if fallback_ok and type(fallback) == "table" then
      return fallback
    end
  end

  return nil, "Backend returned invalid JSON: " .. tostring(response)
end

local function error_from_response(object, response)
  if response and type(response.error) == "table" then
    return vim.deepcopy(response.error)
  end

  local message = vim.trim(object.stderr or "")
  if message == "" then
    message = "Backend process failed with exit code "
      .. tostring(object.code)
  end
  return { code = "BACKEND_ERROR", message = message }
end

function M.run(request, callback, options)
  callback = callback or function() end
  options = options or {}

  local function execute()
    if
      not options.no_definitions
      and request.definitions == nil
      and config().definitions.enabled ~= false
    then
      local collect_ok, definitions = pcall(store().collect)
      if collect_ok and definitions then
        request.definitions = definitions
      end
    end

    local encoded_ok, payload = pcall(vim.json.encode, request)
    if not encoded_ok then
      callback({ code = "ENCODE_ERROR", message = tostring(payload) })
      return
    end

    python().spawn({
      python().python_bin(),
      python().backend_script(),
    }, {
      stdin = payload,
      timeout = config().python.request_timeout,
    }, function(object)
      local response, decode_error = decode_response(object.stdout)

      if response and response.ok == true then
        callback(nil, response)
        return
      end

      if response and response.ok == false then
        callback(error_from_response(object, response))
        return
      end

      if object.code == 124 or object.signal == 9 then
        callback({
          code = "TIMEOUT",
          message = "Backend request timed out",
        })
        return
      end

      callback({
        code = "INVALID_RESPONSE",
        message = decode_error
          or "Backend returned an unexpected response",
        stderr = object.stderr,
        stdout = object.stdout,
      })
    end)
  end

  if options.skip_ensure then
    execute()
    return
  end

  python().ensure(function(ok, message)
    if not ok then
      callback({
        code = "PYTHON_ENVIRONMENT",
        message = message or "Python environment is not ready",
      })
      return
    end
    execute()
  end)
end

return M