-- toolName = "TNS|Model List|TNE"
--
-- Model List (Tools menu script)
--
-- Scans /MODELS/*.yml, reads each model's 'header:' block, and pulls out
-- the 'name' and 'labels' values. Displays "filename: name [labels]" for
-- every model, scrollable with the radio's nav wheel/rotary/pgup-pgdn keys.
--
-- Install: copy to /SCRIPTS/TOOLS/model_list.lua on the SD card.
-- Run from: Radio > Tools > Model List
--
-- Tested against the EdgeTX Lua io/dir API, which only exposes:
--   dir(path)            -- iterator over filenames in a directory
--   io.open/io.read/io.close  -- io.read(file, n) reads n bytes, no line mode
-- so files are read in chunks and split into lines manually.

local MODELS_DIR   = "/MODELS"
local CHUNK_SIZE    = 512
local LINE_HEIGHT   = 22   -- px per text line; tweak if lines look cramped/sparse

local lineBuffer   = {}    -- rows to display, one string per model
local scrollOffset = 0     -- index (0-based) of first visible line
local screenW, screenH

--------------------------------------------------------------------------
-- small string helpers
--------------------------------------------------------------------------

local function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function stripQuotes(s)
  s = trim(s)
  local inner = string.match(s, '^"(.*)"$') or string.match(s, "^'(.*)'$")
  return inner or s
end

local function splitLines(str)
  local lines = {}
  for line in string.gmatch(str .. "\n", "(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

local function getIndent(line)
  local ws = string.match(line,"^(%s*)")
  return #ws
end

--------------------------------------------------------------------------
-- file helpers
--------------------------------------------------------------------------

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local parts = {}
  while true do
    local chunk = io.read(f, CHUNK_SIZE)
    if chunk == nil or chunk == "" then break end
    parts[#parts + 1] = chunk
  end
  io.close(f)
  return table.concat(parts)
end

--------------------------------------------------------------------------
-- YAML-ish header parsing
--
-- Looks for a top-level "header:" key, then walks the indented lines
-- underneath it collecting:
--   name: Foo               -> name = "Foo"
--   labels: A, B             -> labels = "A,B"
-- Stops as soon as indentation returns to the header's own level (i.e.
-- the next top-level key), so it won't wander into unrelated sections.
--------------------------------------------------------------------------

local function parseHeader(lines)
  local name = ""
  local label = ""

  local inHeader, headerIndent = false, nil
  
  for _, line in ipairs(lines) do
    local trimmed = trim(line)

    if not inHeader then
      if trimmed == "header:" then
        inHeader = true
        headerIndent = getIndent(line)
      end
    else
      if trimmed ~= "" then
        local indent = getIndent(line)
        if indent <= headerIndent then
          break -- left the header block
        end

        local key, val = string.match(trimmed,"^([%w_]+):%s*(.*)$")

        if key == "name" then
          name = stripQuotes(val)
        elseif key == "labels" then
          label = stripQuotes(val)
        end
      end
    end
  end

  return name, label
end

--------------------------------------------------------------------------
-- scan /MODELS
--------------------------------------------------------------------------

local function scanModels()
  lineBuffer = {}
  for fname in dir(MODELS_DIR) do
    if string.find (fname, "model[0-9][0-9]?%.yml$") then
      local content = readFile(MODELS_DIR .. "/" .. fname)
      local row
      if content then
        local name, labels = parseHeader(splitLines(content))
        if name == "" then name = "?" end
        row = fname .. ", " .. name .. ", " .. (labels ~= "" and labels or "[unlabelled]")
      else
        row = fname .. ": (could not read file)"
      end
      lineBuffer[#lineBuffer + 1] = row
    end
  end

  if #lineBuffer == 0 then
    lineBuffer[1] = "No .yml files found in " .. MODELS_DIR
  end
end

--------------------------------------------------------------------------
-- EdgeTX script interface
--------------------------------------------------------------------------

local function init()
  screenW, screenH = LCD_W, LCD_H
  scanModels()
end

local function maxVisibleLines()
  local top = LINE_HEIGHT -- leave room for the title row
  return math.max(1, math.floor((screenH - top) / LINE_HEIGHT))
end

local function maxScroll()
  return math.max(0, #lineBuffer - maxVisibleLines())
end

local function run(event)
  if event == EVT_VIRTUAL_EXIT then
    return 1 -- exit the tool
  elseif event == EVT_VIRTUAL_PREV or event == EVT_ROT_LEFT then
    scrollOffset = math.max(0, scrollOffset - 1)
  elseif event == EVT_VIRTUAL_NEXT or event == EVT_ROT_RIGHT then
    scrollOffset = math.min(maxScroll(), scrollOffset + 1)
  elseif event == EVT_VIRTUAL_PAGE_UP then
    scrollOffset = math.max(0, scrollOffset - maxVisibleLines())
  elseif event == EVT_VIRTUAL_PAGE_DOWN then
    scrollOffset = math.min(maxScroll(), scrollOffset + maxVisibleLines())
  end

  lcd.clear()

  lcd.drawText(2, 2, "Model List (" .. #lineBuffer .. ")", INVERS)

  local y = LINE_HEIGHT
  local visible = maxVisibleLines()
  for i = 1, visible do
    local idx = scrollOffset + i
    local text = lineBuffer[idx]
    if not text then break end
    lcd.drawText(2, y, text)
    y = y + LINE_HEIGHT
  end

  -- simple scrollbar indicator on the right edge, if there's more than fits
  if #lineBuffer > visible then
    local barX = screenW - 4
    local trackTop, trackH = LINE_HEIGHT, screenH - LINE_HEIGHT
    local thumbH = math.max(6, trackH * visible / #lineBuffer)
    local thumbY = trackTop + (trackH - thumbH) * (scrollOffset / maxScroll())
    lcd.drawFilledRectangle(barX, trackTop, 3, trackH, GREY_DEFAULT or 0x8410)
    lcd.drawFilledRectangle(barX, thumbY, 3, thumbH, TEXT_COLOR or 0)
  end

  return 0
end

return { init = init, run = run }