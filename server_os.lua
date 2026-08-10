-- server_os.lua - minimal Linux-like server OS for CC: Tweaked
-- Boot via BIOS "Boot other file" (place in root), or rename to startup.
-- Has all standard Linux-like commands (via shell) and runs .sh scripts.

local function runSh(path)
  local f = fs.open(path, "r")
  if not f then print("sh: " .. path .. ": No such file"); return end
  local ln = f.readLine()
  while ln do
    local t = ln:match("^%s*(.-)%s*$")
    if t ~= "" and t:sub(1,1) ~= "#" then shell.run(t) end
    ln = f.readLine()
  end
  f.close()
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.cyan); print("AuroraServer OS  v1.0")
term.setTextColor(colors.lightGray); print("Linux-like shell. 'help' for commands. 'sh file.sh' to run a script.")
term.setTextColor(colors.white)

while true do
  term.setTextColor(colors.green); term.write("root@server")
  term.setTextColor(colors.lightBlue); term.write(" ")
  term.setTextColor(colors.yellow); term.write(shell.dir())
  term.setTextColor(colors.lightGray); term.write("$ ")
  term.setTextColor(colors.white)
  local line = read()
  if line and line:match("%S") then
    local cmd = (line:match("^%s*(%S+)") or ""):lower()
    if cmd == "help" then
      print("Built-in: help sh pwd clear neofetch reboot shutdown exit")
      print("Linux cmds (via shell): ls cd cp mv rm mkdir cat echo edit type ...")
    elseif cmd == "sh" then
      runSh(line:match("^%s*%S+%s+(.+)$") or "")
    elseif cmd == "exit" then break
    elseif cmd == "reboot" then os.reboot()
    elseif cmd == "shutdown" then os.shutdown()
    elseif cmd == "clear" then term.clear(); term.setCursorPos(1,1)
    elseif cmd == "pwd" then print(shell.dir())
    elseif cmd == "neofetch" or cmd == "fastfetch" then
      term.setTextColor(colors.cyan); print("AuroraServer OS  Computer #" .. os.getComputerID())
      term.setTextColor(colors.lightGray)
      print("Label: " .. tostring(os.getComputerLabel() or "(none)"))
      print("Disk: " .. tostring(fs.getFreeSpace("/")) .. " B free")
      term.setTextColor(colors.white)
    else
      shell.run(line)
    end
  end
end
