-- server_os.lua v2.0 - Linux-like server OS for CC: Tweaked
-- Linux commands implemented in Lua (cat/echo/pwd/grep/head/tail/wc/...),
-- standard shell commands (ls/cp/mv/rm/mkdir/edit) via shell,
-- and an `update` command that re-downloads this OS from GitHub.

local SERVER_OS_URL = "https://raw.githubusercontent.com/vanyachickenganidanya-lgtm/ARENAOSFORMINECRAFT/main/server_os.lua"

local function runSh(path)
  local f = fs.open(shell.resolve(path or ""), "r")
  if not f then print("sh: " .. tostring(path) .. ": No such file"); return end
  local ln = f.readLine()
  while ln do
    local t = ln:match("^%s*(.-)%s*$")
    if t ~= "" and t:sub(1,1) ~= "#" then shell.run(t) end
    ln = f.readLine()
  end
  f.close()
end

local cmds = {}
cmds.help = function()
  print("Lua cmds: cat echo pwd touch grep head tail wc clear uname whoami sh update neofetch")
  print("Shell cmds: ls cd cp mv rm mkdir edit type reboot shutdown exit")
end
cmds.cat = function(a)
  local f = fs.open(shell.resolve(a[1] or ""), "r")
  if not f then print("cat: " .. tostring(a[1]) .. ": No such file"); return end
  local l = f.readLine()
  while l do print(l); l = f.readLine() end
  f.close()
end
cmds.echo = function(a) print(table.concat(a, " ")) end
cmds.pwd = function() print(shell.dir()) end
cmds.touch = function(a) local p = shell.resolve(a[1] or ""); local f = fs.open(p, "w"); if f then f.close() else print("touch: cannot create " .. tostring(a[1])) end end
cmds.grep = function(a)
  if not a[1] or not a[2] then print("usage: grep PATTERN FILE"); return end
  local pat, fname = a[1], shell.resolve(a[2])
  local f = fs.open(fname, "r")
  if not f then print("grep: " .. a[2] .. ": No such file"); return end
  local l = f.readLine()
  while l do if l:find(pat, 1, true) then print(l) end; l = f.readLine() end
  f.close()
end
cmds.head = function(a)
  local fname = shell.resolve(a[1] or ""); local count = tonumber(a[2]) or 10
  if not a[1] then print("usage: head FILE [N]"); return end
  local f = fs.open(fname, "r")
  if not f then print("head: " .. a[1] .. ": No such file"); return end
  local l = f.readLine(); local i = 0
  while l and i < count do print(l); i = i + 1; l = f.readLine() end
  f.close()
end
cmds.tail = function(a)
  local fname = shell.resolve(a[1] or ""); local count = tonumber(a[2]) or 10
  if not a[1] then print("usage: tail FILE [N]"); return end
  local f = fs.open(fname, "r")
  if not f then print("tail: " .. a[1] .. ": No such file"); return end
  local buf = {}; local l = f.readLine()
  while l do buf[#buf + 1] = l; l = f.readLine() end
  f.close()
  for i = math.max(1, #buf - count + 1), #buf do print(buf[i]) end
end
cmds.wc = function(a)
  local fname = shell.resolve(a[1] or "")
  if not a[1] then print("usage: wc FILE"); return end
  local f = fs.open(fname, "r")
  if not f then print("wc: " .. a[1] .. ": No such file"); return end
  local lines, words, chars = 0, 0, 0
  local l = f.readLine()
  while l do
    lines = lines + 1; chars = chars + #l + 1
    for _ in l:gmatch("%S+") do words = words + 1 end
    l = f.readLine()
  end
  f.close()
  print(lines .. " " .. words .. " " .. chars .. " " .. a[1])
end
cmds.clear = function() term.clear(); term.setCursorPos(1, 1) end
cmds.uname = function() print("AuroraServer OS") end
cmds.whoami = function() print("root") end
cmds.sh = function(a) runSh(a[1]) end
cmds.cd = function(a)
  local d = a[1] or "/"
  local nd = shell.resolve(d)
  if fs.isDir(nd) then shell.setDir(nd) else print("cd: not a directory: " .. d) end
end
cmds.neofetch = function()
  term.setTextColor(colors.cyan); print("AuroraServer OS  Computer #" .. os.getComputerID())
  term.setTextColor(colors.lightGray)
  print("Label: " .. tostring(os.getComputerLabel() or "(none)"))
  print("Disk:  " .. tostring(fs.getFreeSpace("/")) .. " B free")
  print("Dir:   " .. shell.dir())
  term.setTextColor(colors.white)
end
cmds.fastfetch = cmds.neofetch
cmds.exit = function() return "exit" end
cmds.reboot = function() os.reboot() end
cmds.shutdown = function() os.shutdown() end
cmds.update = function()
  print("Updating Server OS from GitHub...")
  local h = http.get(SERVER_OS_URL)
  if not h then print("Failed: HTTP off? or server_os.lua not in repo?") return end
  local b = h.readAll(); h.close()
  if not b or b == "" then print("Empty response") return end
  local f = fs.open("/server_os.lua", "w"); f.write(b); f.close()
  print("Updated. Rebooting..."); sleep(1.2); os.reboot()
end

-- add /bin to PATH so user-dropped command scripts are found
if not fs.isDir("/bin") then fs.makeDir("/bin") end
shell.setPath(shell.path() .. ":/bin")

term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1, 1)
term.setTextColor(colors.cyan); print("AuroraServer OS  v2.0")
term.setTextColor(colors.lightGray); print("Linux-like shell. 'help' for commands. 'update' to self-update.")
term.setTextColor(colors.white)

while true do
  term.setTextColor(colors.green); term.write("root@server")
  term.setTextColor(colors.yellow); term.write(" " .. shell.dir() .. " ")
  term.setTextColor(colors.lightGray); term.write("$ ")
  term.setTextColor(colors.white)
  local line = read()
  if line and line:match("%S") then
    local args = {}
    for w in line:gmatch("%S+") do args[#args + 1] = w end
    local cmd = table.remove(args, 1):lower()
    if cmds[cmd] then
      if cmds[cmd](args) == "exit" then break end
    else
      shell.run(line)
    end
  end
end
