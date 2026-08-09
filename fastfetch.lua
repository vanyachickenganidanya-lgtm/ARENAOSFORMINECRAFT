-- fastfetch.lua - system info for AuroraOS (neofetch style). ASCII only.
-- Place in /apps (desktop icon) or run from terminal.

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
local W, H = term.getSize()

local LOGO = {
  "      .:::::::::::::::.      ",
  "    .'                 '.    ",
  "   .   A  U  R  O  R  A   .  ",
  "   .         O S          .  ",
  "    '.                 .'    ",
  "      ':::::::::::::::'      ",
}

local ver = "?"
local f = fs.open("/startup", "r")
if f then
  local s = f.readAll(); f.close()
  local DQ = string.char(34)
  local v = s:match("VERSION%s*=%s*" .. DQ .. "([^" .. DQ .. "]+)" .. DQ)
  if v then ver = v end
end

local id = os.getComputerID()
local label = os.getComputerLabel() or "none"
local host
if turtle then host = "Turtle #" .. id
elseif pocket then host = "Pocket #" .. id
else host = "Computer #" .. id end
local ccver = tostring(os.version())
local up = math.floor(os.clock() or 0)
local free = fs.getFreeSpace("/") or 0
local freeKB = math.floor(free / 1024)
local accent = colors.cyan

local function drawLine(x, y, txt, col)
  term.setCursorPos(x, y)
  term.setTextColor(col or colors.white)
  term.write(txt)
end

local lx, ly = 2, 2
for i, l in ipairs(LOGO) do drawLine(lx, ly + i - 1, l, accent) end

local wide = W >= 38
local ix = wide and (lx + #LOGO[1] + 2) or 2
local iy = wide and ly or (ly + #LOGO + 1)

local function row(label, val, y, vc)
  term.setCursorPos(ix, y)
  term.setTextColor(colors.lightGray); term.write(label .. " ")
  term.setTextColor(vc or colors.white); term.write(tostring(val))
end

drawLine(ix, iy, "AuroraOS " .. ver, accent)
drawLine(ix, iy + 1, string.rep("-", 16), colors.gray)
row("Host:", host, iy + 2)
row("CC:", ccver, iy + 3)
row("Label:", label, iy + 4)
row("Uptime:", up .. " s", iy + 5)
row("Resolution:", W .. "x" .. H, iy + 6)
row("Disk:", freeKB .. " KB free (" .. free .. " B)", iy + 7)

term.setTextColor(colors.lightGray)
term.setCursorPos(1, H)
term.write("[any key / click] close")

local t = os.startTimer(5)
while true do
  local e = { os.pullEvent() }
  if e[1] == "key" or e[1] == "mouse_click" or e[1] == "monitor_touch" then break end
  if e[1] == "timer" and e[2] == t then break end
end
