-- /.system/server/commands.lua  - command module for AuroraServer OS
-- Loaded by /server_os.lua. Returns { run=..., cmds=..., <each command> }.

local STDIN
local function readLines(path)
  local f = fs.open(path, "r"); if not f then return nil end
  local t = {}; local l = f.readLine()
  while l do t[#t + 1] = l; l = f.readLine() end
  f.close(); return t
end
local function splitLines(s)
  if not s then return {} end
  local t = {}; for line in (s .. "\n"):gmatch("(.-)\n") do t[#t + 1] = line end
  return t
end
local function putlines(lines) for _, l in ipairs(lines) do print(l) end end
local function fileLines(a, i)
  i = i or 1
  if a[i] then
    local out = {}
    for j = i, #a do local l = readLines(shell.resolve(a[j])); if l then for _, x in ipairs(l) do out[#out + 1] = x end else print("cat: " .. a[j] .. ": No such file") end end
    return out
  end
  return splitLines(STDIN)
end

local function lineCapture()
  local lines = {}; local cur = ""; local y = 1
  local t = {}
  t.write = function(s) cur = cur .. tostring(s) end
  t.setCursorPos = function(_, ny) if type(ny) == "number" and ny > y then lines[#lines + 1] = cur; cur = ""; y = ny end end
  t.scroll = function() end; t.clear = function() lines = {}; cur = ""; y = 1 end; t.clearLine = function() cur = "" end
  t.getSize = function() local w = term.getSize(); return w, 10000 end
  t.getCursorPos = function() return 1, y end
  t.setTextColor = function() end; t.setBackgroundColor = function() end; t.isColor = function() return false end
  t.setCursorBlink = function() end; t.blit = function() end
  setmetatable(t, { __index = function() return function() end end })
  return t, function() lines[#lines + 1] = cur; while #lines > 0 and lines[#lines] == "" do lines[#lines] = nil end; return table.concat(lines, "\n") end
end

local function flags(a)
  local f = {}; local i = 1
  while a[i] and a[i]:sub(1, 1) == "-" and #a[i] > 1 do for ch in a[i]:gmatch(".") do f[ch] = true end; i = i + 1 end
  return f, i
end

local cmds = {}
cmds.help = function()
  print("cat echo pwd touch grep head tail wc sort uniq tee find tree less more")
  print("date sleep which basename dirname du df env uname whoami clear nano man sh cd neofetch history")
  print("Shell: ls cp mv rm mkdir edit type alias reboot shutdown exit")
  print("Pipes: cat a b | grep -i x | sort -r | head -3")
end
cmds.cat = function(a)
  if #a == 0 then putlines(splitLines(STDIN)); return end
  for _, fname in ipairs(a) do
    local l = readLines(shell.resolve(fname))
    if l then putlines(l) else print("cat: " .. fname .. ": No such file") end
  end
end
cmds.echo = function(a) print(table.concat(a, " ")) end
cmds.pwd = function() print(shell.dir()) end
cmds.touch = function(a) for _, f in ipairs(a) do local h = fs.open(shell.resolve(f), "w"); if h then h.close() else print("touch: cannot create " .. f) end end end
cmds.grep = function(a)
  local f, i = flags(a)
  local pat = a[i]; if not pat then print("usage: grep [-inv] PATTERN [FILE]") return end
  local lines = a[i + 1] and (readLines(shell.resolve(a[i + 1])) or {}) or splitLines(STDIN)
  local p = f.i and pat:lower() or pat
  for n, l in ipairs(lines) do
    local ll = f.i and l:lower() or l
    local m = ll:find(p, 1, true)
    if (m and not f.v) or (not m and f.v) then print((f.n and (n .. ":") or "") .. l) end
  end
end
cmds.head = function(a)
  local f, i = flags(a); local count = tonumber(a[i]) or 10
  if a[i] and tonumber(a[i]) then i = i + 1 end
  local lines = fileLines(a, i)
  for n = 1, math.min(count, #lines) do print(lines[n]) end
end
cmds.tail = function(a)
  local f, i = flags(a); local count = tonumber(a[i]) or 10
  if a[i] and tonumber(a[i]) then i = i + 1 end
  local lines = fileLines(a, i)
  for n = math.max(1, #lines - count + 1), #lines do print(lines[n]) end
end
cmds.wc = function(a)
  local f, i = flags(a)
  local lines = a[i] and (readLines(shell.resolve(a[i])) or {}) or splitLines(STDIN)
  local words, chars = 0, 0
  for _, l in ipairs(lines) do chars = chars + #l + 1; for _ in l:gmatch("%S+") do words = words + 1 end end
  if f.l then print(#lines) elseif f.w then print(words) elseif f.c then print(chars) else print(#lines .. " " .. words .. " " .. chars .. " " .. (a[i] or "")) end
end
cmds.sort = function(a)
  local f, i = flags(a)
  local lines = a[i] and (readLines(shell.resolve(a[i])) or {}) or splitLines(STDIN)
  table.sort(lines, function(x, y) if f.n then return (tonumber(x) or 0) < (tonumber(y) or 0) else return x < y end end)
  if f.r then local r = {}; for j = #lines, 1, -1 do r[#r + 1] = lines[j] end; lines = r end
  putlines(lines)
end
cmds.uniq = function(a)
  local f, i = flags(a)
  local lines = a[i] and (readLines(shell.resolve(a[i])) or {}) or splitLines(STDIN)
  local prev; for _, l in ipairs(lines) do if l ~= prev then print(l); prev = l end end
end
cmds.tee = function(a)
  local lines = splitLines(STDIN)
  for _, fn in ipairs(a) do local h = fs.open(shell.resolve(fn), "w"); if h then for _, l in ipairs(lines) do h.write(l .. "\n") end; h.close() end end
  putlines(lines)
end
cmds.find = function(a)
  local start = shell.resolve(a[1] or "."); local pat = a[2]
  local function walk(d) if fs.isDir(d) then for _, fn in ipairs(fs.list(d)) do local full = fs.combine(d, fn); if (not pat) or full:find(pat, 1, true) then print(full) end; if fs.isDir(full) then walk(full) end end end end
  walk(start)
end
cmds.tree = function(a)
  local root = shell.resolve(a[1] or ".")
  local function walk(d, pre)
    local items = fs.list(d) or {}
    for i, fn in ipairs(items) do
      local last = (i == #items); local full = fs.combine(d, fn)
      print(pre .. (last and "`- " or "|- ") .. fn .. (fs.isDir(full) and "/" or ""))
      if fs.isDir(full) then walk(full, pre .. (last and "   " or "|  ")) end
    end
  end
  print(root); walk(root, "")
end
cmds.less = function(a)
  local f, i = flags(a)
  local lines = a[i] and (readLines(shell.resolve(a[i])) or {}) or splitLines(STDIN)
  local _, h = term.getSize(); local top = 1
  if #lines == 0 then print("(empty)") return end
  while true do
    term.clear(); term.setCursorPos(1, 1)
    for n = top, math.min(top + h - 2, #lines) do print(lines[n]) end
    term.setCursorPos(1, h); term.write(": q=quit  space/Up/Down")
    local _, p = os.pullEvent("key")
    if p == keys.q or p == keys.esc then break
    elseif p == keys.space or p == keys.down or p == keys.pageDown then top = math.min(top + h - 2, #lines)
    elseif p == keys.up or p == keys.pageUp then top = math.max(1, top - (h - 2)) end
  end
  term.clear(); term.setCursorPos(1, 1)
end
cmds.more = cmds.less
cmds.nano = function(a) shell.run("edit", a[1] or "") end
cmds.man = function() cmds.help() end
cmds.date = function() print(tostring(os.date("%a %b %d %H:%M:%S"))) end
cmds.sleep = function(a) sleep(tonumber(a[1]) or 1) end
cmds.which = function(a) for _, c in ipairs(a) do print(shell.resolveProgram(c) or (c .. ": not found")) end end
cmds.basename = function(a) print(fs.getName(a[1] or "")) end
cmds.dirname = function(a) print(fs.getDir(a[1] or "/")) end
cmds.df = function() print("/  " .. tostring(fs.getFreeSpace("/")) .. " B free") end
cmds.du = function(a)
  local d = shell.resolve(a[1] or "."); local total = 0
  local function walk(p) if fs.isDir(p) then for _, fn in ipairs(fs.list(p)) do walk(fs.combine(p, fn)) end else total = total + (fs.getSize(p) or 0) end end
  walk(d); print(total .. "  " .. d)
end
cmds.env = function() print("PATH=" .. shell.path()); for k, v in pairs(shell.aliases()) do print(k .. "=" .. v) end end
cmds.uname = function() print("AuroraServer OS  Computer #" .. os.getComputerID()) end
cmds.whoami = function() print("root") end
cmds.clear = function() term.clear(); term.setCursorPos(1, 1) end
cmds.sh = function(a)
  local f = fs.open(shell.resolve(a[1] or ""), "r")
  if not f then print("sh: " .. tostring(a[1]) .. ": No such file"); return end
  local ln = f.readLine()
  while ln do local t = ln:match("^%s*(.-)%s*$"); if t ~= "" and t:sub(1, 1) ~= "#" then runLine(t) end; ln = f.readLine() end
  f.close()
end
cmds.cd = function(a) local d = a[1] or "/"; local nd = shell.resolve(d); if fs.isDir(nd) then shell.setDir(nd) else print("cd: not a directory: " .. d) end end
cmds.neofetch = function()
  term.setTextColor(colors.cyan); print("AuroraServer OS")
  term.setTextColor(colors.lightGray)
  print("Computer #" .. os.getComputerID() .. "  Label: " .. tostring(os.getComputerLabel() or "(none)"))
  print("Disk: " .. tostring(fs.getFreeSpace("/")) .. " B free  Dir: " .. shell.dir())
  term.setTextColor(colors.white)
end
cmds.fastfetch = cmds.neofetch
cmds.history = function() for i, l in ipairs(HISTORY or {}) do print(i .. "  " .. l) end end
cmds.exit = function() _G.EXIT = true end
cmds.reboot = function() os.reboot() end
cmds.shutdown = function() os.shutdown() end

local function runSeg(segline, capture)
  local args = {}; for w in segline:gmatch("%S+") do args[#args + 1] = w end
  local cmd = table.remove(args, 1); if not cmd then return "" end; cmd = cmd:lower()
  local function exec() if cmds[cmd] then cmds[cmd](args) else shell.run(segline) end end
  if capture then local cap, get = lineCapture(); local prev = term.redirect(cap); exec(); term.redirect(prev); return get() else exec(); return nil end
end

function runLine(line)
  local segs = {}; for s in line:gmatch("[^|]+") do segs[#segs + 1] = s:match("^%s*(.-)%s*$") end
  if #segs == 0 then return end
  if #segs == 1 then STDIN = nil; runSeg(segs[1], false); return end
  local input = nil
  for i = 1, #segs do STDIN = input; if i == #segs then runSeg(segs[i], false) else input = runSeg(segs[i], true) end end
  STDIN = nil
end

local M = { run = runLine, cmds = cmds }
for k, v in pairs(cmds) do M[k] = v end
return M
