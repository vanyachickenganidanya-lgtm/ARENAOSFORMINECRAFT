-- server_os.lua v4.0 - AuroraServer OS bootstrap
-- Commands module lives in /.system/server/commands.lua (auto-downloaded).
local BASE = "https://raw.githubusercontent.com/vanyachickenganidanya-lgtm/ARENAOSFORMINECRAFT/main"
local MOD = "/.system/server/commands.lua"

local function fetch(url, dest)
  local h = http.get(url); if not h then return false end
  local b = h.readAll(); h.close()
  if not b or b == "" then return false end
  local d = fs.getDir(dest); if not fs.isDir(d) then fs.makeDir(d) end
  local f = fs.open(dest, "w"); f.write(b); f.close(); return true
end

if not fs.exists(MOD) then
  print("Fetching commands module from GitHub...")
  if not fetch(BASE .. "/server_commands.lua", MOD) then
    print("Failed. Enable HTTP or put server_commands.lua at " .. MOD)
  end
end

local ok, C = pcall(dofile, MOD)
if not ok or type(C) ~= "table" then
  print("ERROR: cannot load " .. MOD)
  if not ok then print(tostring(C)) end
  print("Fix HTTP / file, then reboot and run 'update'.")
  term.clear(); term.setCursorPos(1, 1)
  while true do term.setTextColor(colors.lightGray); term.write("> "); shell.run(read() or "") end
end

_G.server = C
HISTORY = {}
if not fs.isDir("/bin") then fs.makeDir("/bin") end
shell.setPath(shell.path() .. ":/bin")

EXIT = false
term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1, 1)
term.setTextColor(colors.cyan); print("AuroraServer OS  v4.0  (modular)")
term.setTextColor(colors.lightGray); print("Linux-like. 'help' for commands. Pipes: cat a b | grep -i x | head. 'update' to self-update.")
term.setTextColor(colors.white)

while not EXIT do
  term.setTextColor(colors.green); term.write("root@server")
  term.setTextColor(colors.yellow); term.write(" " .. shell.dir() .. " ")
  term.setTextColor(colors.lightGray); term.write("$ ")
  term.setTextColor(colors.white)
  local line = read(nil, HISTORY)
  if line and line:match("%S") then
    HISTORY[#HISTORY + 1] = line
    local cmd = (line:match("^%s*(%S+)") or ""):lower()
    if cmd == "update" then
      print("Updating AuroraServer OS...")
      local ok1 = fetch(BASE .. "/server_os.lua", "/server_os.lua")
      local ok2 = fetch(BASE .. "/server_commands.lua", MOD)
      print((ok1 and ok2) and "Updated. Rebooting..." or "Update failed (HTTP off?)")
      sleep(1.2); os.reboot()
    else
      C.run(line)
    end
  end
end
