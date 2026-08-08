local OSNAME = "AuroraOS"
local OS_URL = "https://raw.githubusercontent.com/vanyachickenganidanya-lgtm/ARENAOSFORMINECRAFT/main/aurora_os.lua"
local ACCENTS = { colors.cyan, colors.lightBlue, colors.purple, colors.magenta, colors.lime, colors.orange, colors.red, colors.green }
local ANAMES  = { "cyan", "blue", "purple", "magenta", "lime", "orange", "red", "green" }

local function hash(s)
  s = "aur0ra$"..(s or "").."$salt"; local h,g = 5381,0
  for i=1,#s do h=(h*33+string.byte(s,i))%1000000007 end
  for i=1,#s do g=(g*31+(string.byte(s,i)*7+3))%1000000007 end
  return string.format("%08x",(h*1000003+g)%1000000007)
end
local function readMasked()
  local s=""
  while true do
    local ev,p1=os.pullEvent()
    if ev=="char" then s=s..p1; term.write("*")
    elseif ev=="key" and p1==keys.enter then return s
    elseif ev=="key" and p1==keys.backspace and #s>0 then
      s=s:sub(1,#s-1); local x,y=term.getCursorPos(); term.setCursorPos(x-1,y); term.write(" "); term.setCursorPos(x-1,y)
    end
  end
end
local function head(t)
  term.clear(); term.setCursorPos(1,1)
  term.setTextColor(colors.cyan); print("================================"); print("   "..OSNAME.." - INSTALLER"); print("================================"); term.setTextColor(colors.white)
  if t then print("") end
end
local function ask(p) term.setTextColor(colors.lightGray); term.write(p); term.setTextColor(colors.white) end
local function download(url, dest)
  local h = http.get(url)
  if not h then return false end
  local b = h.readAll(); h.close()
  if not b or b=="" then return false end
  local f = fs.open(dest,"w"); f.write(b); f.close(); return true
end

head(true)
print("This will download and install "..OSNAME.." on this computer.")
print("")

if OS_URL:find("USER") then
  ask("GitHub raw URL of aurora_os.lua: "); OS_URL = read() or OS_URL
  print("")
end
if OS_URL:find("USER") then print("No URL given. Aborting."); return end

local mode
while not mode do
  print("Choose mode:")
  term.setTextColor(colors.lime); print("  [1] Console (nice console, no GUI)")
  term.setTextColor(colors.lightBlue); print("  [2] Graphics (desktop, mouse)")
  term.setTextColor(colors.white)
  ask("Your choice [1/2]: "); local c=read()
  if c=="1" then mode="console" elseif c=="2" then mode="gui" end
end

head(true) print("Accent color:")
for i=1,#ACCENTS do term.setTextColor(ACCENTS[i]); print("  ["..i.."] "..ANAMES[i]) end
term.setTextColor(colors.white)
ask("Color number [1-8, Enter=cyan]: "); local ci=tonumber(read()); local accent=ACCENTS[ci] or colors.cyan

local admin, pass
head(true) print("Create admin:")
ask("Admin name: "); admin=read(); if not admin or admin=="" then admin="admin" end
ask("Password (empty = none): "); pass=readMasked()
if pass=="" then pass=nil end

head(true)
term.setTextColor(colors.white)
print("Mode:   "..(mode=="gui" and "graphics" or "console"))
print("Color:  "..(ANAMES[ci] or "cyan"))
print("Admin:  "..admin..(pass and " (with password)" or " (no password)"))
print("")
ask("Install? [y/n]: "); local conf=read()
if conf:lower()~="y" and conf~="" then print("Install cancelled."); return end

print("")
term.setTextColor(colors.cyan); print("Downloading OS from GitHub..."); term.setTextColor(colors.white)
if not download(OS_URL, "/startup") then
  term.setTextColor(colors.red); print("Download failed.")
  print("Check: HTTP enabled + raw.githubusercontent.com allowed?")
  return
end

fs.makeDir("/.system")
local cfg={mode=mode, accent=accent, users={{name=admin, hash=pass and hash(pass) or nil, admin=true}}, rn_target=16}
local f=fs.open("/.system/config","w"); f.write(textutils.serialize(cfg)); f.close()

term.setTextColor(colors.lime); print(""); print("Install complete! Rebooting...")
sleep(1.5); os.reboot()
