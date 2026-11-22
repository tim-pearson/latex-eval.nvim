local M = {}

local ALIGNED_ENVIRONMENTS = {
  align = true,
  ["align*"] = true,
  gather = true,
  ["gather*"] = true,
  aligned = true,
}

local function ui()
  return require("latex-eval.ui")
end

local function trim(value)
  return vim.trim(value or "")
end

local function is_escaped(text, index)
  local cursor = index - 1
  local backslashes = 0
  while cursor >= 1 and text:sub(cursor, cursor) == "\\" do
    backslashes = backslashes + 1
    cursor = cursor - 1
  end
  return backslashes % 2 == 1
end

local function line_starts(lines)
  local starts = { 1 }
  local offset = 1
  for index = 1, #lines do
    offset = offset + #lines[index] + 1
    starts[index + 1] = offset
  end
  return starts
end

local function row_for_offset(starts, offset)
  local row = 0
  for index = 1, #starts do
    if starts[index] <= offset then
      row = index - 1
    else
      break
    end
  end
  return row
end

local function display_contents(text)
  local blocks = {}
  local search = 1
  while true do
    local open_start = text:find("$$", search, true)
    if not open_start then
      break
    end
    if is_escaped(text, open_start) then
      search = open_start + 1
    else
      local close_start = text:find("$$", open_start + 2, true)
      while close_start and is_escaped(text, close_start) do
        close_start = text:find("$$", close_start + 1, true)
      end
      if not close_start then
        break
      end
      blocks[#blocks + 1] = {
        content = text:sub(open_start + 2, close_start - 1),
        start_offset = open_start,
        end_offset = close_start,
      }
      search = close_start + 2
    end
  end
  return blocks
end

local function display_blocks(lines)
  local text = table.concat(lines, "\n")
  local starts = line_starts(lines)
  local blocks = {}
  for _, block in ipairs(display_contents(text)) do
    blocks[#blocks + 1] = {
      content = block.content,
      start_row = row_for_offset(starts, block.start_offset),
      end_row = row_for_offset(starts, block.end_offset),
    }
  end
  return blocks
end

local function indent_of(lines)
  for _, line in ipairs(lines) do
    if trim(line) ~= "" then
      return line:match("^%s*") or ""
    end
  end
  return ""
end

local function prefix_lines(lines, indent)
  if not indent or indent == "" then
    return lines
  end
  local prefixed = {}
  for _, line in ipairs(lines) do
    prefixed[#prefixed + 1] = indent .. line
  end
  return prefixed
end

local function split_aligned_rows(content)
  local rows = {}
  local current = {}
  local depth = 0
  local index = 1
  while index <= #content do
    local character = content:sub(index, index)
    local next_character = content:sub(index + 1, index + 1)
    if character == "\\" and next_character == "\\" and depth == 0 then
      rows[#rows + 1] = table.concat(current)
      current = {}
      index = index + 2
    elseif character == "{" then
      depth = depth + 1
      current[#current + 1] = character
      index = index + 1
    elseif character == "}" then
      depth = math.max(depth - 1, 0)
      current[#current + 1] = character
      index = index + 1
    else
      current[#current + 1] = character
      index = index + 1
    end
  end
  rows[#rows + 1] = table.concat(current)
  return rows
end

local function align_row(row)
  if row:find("&", 1, true) then
    return row
  end

  local depth = 0
  local index = 1
  while index <= #row do
    local character = row:sub(index, index)
    if character == "\\" then
      index = index + 2
    elseif character == "{" then
      depth = depth + 1
      index = index + 1
    elseif character == "}" then
      depth = math.max(depth - 1, 0)
      index = index + 1
    elseif character == "=" and depth == 0 then
      local lhs = trim(row:sub(1, index - 1))
      local rhs = trim(row:sub(index + 1))
      if lhs ~= "" and rhs ~= "" then
        return lhs .. " &= " .. rhs
      end
      return row
    else
      index = index + 1
    end
  end

  return row
end

local function unalign_row(row)
  local lhs, rhs = row:match("^(.-)%s*&%s*=%s*(.*)$")
  if lhs and rhs and not lhs:find("&", 1, true) and not rhs:find("&", 1, true) then
    return trim(lhs) .. " = " .. trim(rhs)
  end
  return row
end

function M._join_text(text, indent)
  local blocks = display_contents(text)
  if #blocks < 2 then
    return nil, "Join requires at least two $$ blocks"
  end

  if trim(text:sub(1, blocks[1].start_offset - 1)) ~= "" then
    return nil, "Join only works on a region containing $$ blocks"
  end
  for index = 2, #blocks do
    local between = text:sub(
      blocks[index - 1].end_offset + 2,
      blocks[index].start_offset - 1
    )
    if trim(between) ~= "" then
      return nil, "Join only works on a region containing $$ blocks"
    end
  end
  if trim(text:sub(blocks[#blocks].end_offset + 2)) ~= "" then
    return nil, "Join only works on a region containing $$ blocks"
  end

  local rows = {}
  for _, block in ipairs(blocks) do
    local content = trim(block.content)
    if content == "" then
      return nil, "Cannot join an empty $$ block"
    end
    if content:find("\n", 1, true) then
      return nil, "Join requires one expression per $$ block"
    end
    rows[#rows + 1] = align_row(content)
  end

  local lines = { "$$", "\\begin{align*}" }
  for index, row in ipairs(rows) do
    if index < #rows then
      lines[#lines + 1] = row .. " \\\\"
    else
      lines[#lines + 1] = row
    end
  end
  lines[#lines + 1] = "\\end{align*}"
  lines[#lines + 1] = "$$"
  return prefix_lines(lines, indent or "")
end

function M._split_text(text, indent)
  local search = 1
  local environment = nil
  local begin_start = nil
  local begin_end = nil
  while true do
    local found_start, found_end, name =
      text:find("\\begin{([^}]+)}", search)
    if not found_start then
      break
    end
    if ALIGNED_ENVIRONMENTS[name] then
      environment = name
      begin_start = found_start
      begin_end = found_end
      break
    end
    search = found_end + 1
  end

  if not environment then
    return nil, "No aligned math environment found"
  end

  local prefix = trim(text:sub(1, begin_start - 1))
  if prefix ~= "" and prefix ~= "$$" then
    return nil, "Split only works on an aligned math block"
  end

  local end_marker = "\\end{" .. environment .. "}"
  local end_start, end_end = text:find(end_marker, begin_end + 1, true)
  if not end_start then
    return nil, "Missing " .. end_marker
  end

  local suffix = trim(text:sub(end_end + 1))
  if suffix ~= "" and suffix ~= "$$" then
    return nil, "Split only works on an aligned math block"
  end

  local content = text:sub(begin_end + 1, end_start - 1)
  local rows = {}
  for _, row in ipairs(split_aligned_rows(content)) do
    local value = trim(row)
    if value ~= "" then
      rows[#rows + 1] = unalign_row(value)
    end
  end
  if #rows == 0 then
    return nil, "Aligned environment is empty"
  end

  local lines = {}
  for index, row in ipairs(rows) do
    if index > 1 then
      lines[#lines + 1] = ""
    end
    lines[#lines + 1] = "$$"
    lines[#lines + 1] = row
    lines[#lines + 1] = "$$"
  end
  return prefix_lines(lines, indent or "")
end

local function contains_aligned_environment(text)
  local search = 1
  while true do
    local begin_start, begin_end, name =
      text:find("\\begin{([^}]+)}", search)
    if not begin_start then
      return false
    end
    if ALIGNED_ENVIRONMENTS[name] then
      return true
    end
    search = begin_end + 1
  end
end

local function region_from_lines(bufnr, start_row, end_row)
  return {
    bufnr = bufnr,
    start_row = start_row,
    end_row = end_row,
    lines = vim.api.nvim_buf_get_lines(
      bufnr,
      start_row,
      end_row + 1,
      false
    ),
  }
end

local function visual_region()
  local raw = require("latex-eval.selection").get_visual_raw()
  if not raw or not raw.range then
    return nil
  end
  local bufnr = 0
  return region_from_lines(bufnr, raw.range.start_row, raw.range.end_row)
end

local function align_region(lines, cursor_row)
  local text = table.concat(lines, "\n")
  local starts = line_starts(lines)
  local search = 1

  while true do
    local begin_start, begin_end, name =
      text:find("\\begin{([^}]+)}", search)
    if not begin_start then
      return nil
    end
    if not ALIGNED_ENVIRONMENTS[name] then
      search = begin_end + 1
    else
      local end_marker = "\\end{" .. name .. "}"
      local end_start, end_end = text:find(end_marker, begin_end + 1, true)
      if not end_start then
        return nil
      end

      local start_row = row_for_offset(starts, begin_start)
      local row_end = row_for_offset(starts, end_start)
      if cursor_row >= start_row and cursor_row <= row_end then
        local first = start_row
        local last = row_end

        local previous = first - 1
        while previous >= 0 and trim(lines[previous + 1]) == "" do
          previous = previous - 1
        end
        if previous >= 0 and trim(lines[previous + 1]) == "$$" then
          first = previous
        end

        local following = last + 1
        while following < #lines and trim(lines[following + 1]) == "" do
          following = following + 1
        end
        if following < #lines and trim(lines[following + 1]) == "$$" then
          last = following
        end

        return region_from_lines(0, first, last)
      end
      search = end_end + 1
    end
  end
end

local function join_region(lines, cursor_row)
  local blocks = display_blocks(lines)
  local selected = nil
  for index, block in ipairs(blocks) do
    if cursor_row >= block.start_row and cursor_row <= block.end_row then
      selected = index
      break
    end
  end
  if not selected then
    return nil
  end

  local first = selected
  local last = selected
  while first > 1 do
    local gap_start = blocks[first - 1].end_row + 1
    local gap_end = blocks[first].start_row - 1
    local blank = true
    for row = gap_start, gap_end do
      if trim(lines[row + 1]) ~= "" then
        blank = false
        break
      end
    end
    if not blank then
      break
    end
    first = first - 1
  end
  while last < #blocks do
    local gap_start = blocks[last].end_row + 1
    local gap_end = blocks[last + 1].start_row - 1
    local blank = true
    for row = gap_start, gap_end do
      if trim(lines[row + 1]) ~= "" then
        blank = false
        break
      end
    end
    if not blank then
      break
    end
    last = last + 1
  end

  return region_from_lines(
    0,
    blocks[first].start_row,
    blocks[last].end_row
  )
end

local function apply_region(region, lines)
  vim.api.nvim_buf_set_lines(
    region.bufnr,
    region.start_row,
    region.end_row + 1,
    false,
    lines
  )
  pcall(vim.api.nvim_win_set_cursor, 0, { region.start_row + 1, 0 })
end

function M.join_region(region)
  local indent = indent_of(region.lines)
  local text = table.concat(region.lines, "\n")
  local lines, error_message = M._join_text(text, indent)
  if not lines then
    ui().warn(error_message)
    return false
  end
  apply_region(region, lines)
  return true
end

function M.split_region(region)
  local indent = indent_of(region.lines)
  local text = table.concat(region.lines, "\n")
  local lines, error_message = M._split_text(text, indent)
  if not lines then
    ui().warn(error_message)
    return false
  end
  apply_region(region, lines)
  return true
end

local function run(kind)
  local mode = vim.fn.mode()
  local region = nil
  local action = kind

  if mode == "v" or mode == "V" or mode == "\22" then
    region = visual_region()
    if not region then
      ui().warn("No visual selection is available")
      return
    end
    if kind == "toggle" then
      action = contains_aligned_environment(table.concat(region.lines, "\n"))
          and "split"
        or "join"
    end
  else
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    if kind == "toggle" then
      region = align_region(lines, cursor_row)
      if region then
        action = "split"
      else
        region = join_region(lines, cursor_row)
        action = "join"
      end
    elseif kind == "split" then
      region = align_region(lines, cursor_row)
    else
      region = join_region(lines, cursor_row)
    end

    if not region then
      ui().warn("No math block found at the cursor")
      return
    end
  end

  if action == "split" then
    M.split_region(region)
  else
    M.join_region(region)
  end
end

function M.join()
  run("join")
end

function M.split()
  run("split")
end

function M.toggle()
  run("toggle")
end

return M