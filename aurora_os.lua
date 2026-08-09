local OSNAME, VERSION = "AuroraOS", "4.0"
local CFGPATH = "/.system/config"
local ACCENTS = { colors.cyan, colors.lightBlue, colors.purple, colors.magenta, colors.lime, colors.orange, colors.red, colors.green }
local CTRL, SECRET, ACK = 48321, "k7s9m2x", 31337
local OS_SOURCE = "https://raw.githubusercontent.com/vanyachickenganidanya-lgtm/ARENAOSFORMINECRAFT/main/aurora_os.lua"
local VERSION_URL = "https://raw.githubusercontent.com/vanyachickenganidanya-lgtm/ARENAOSFORMINECRAFT/main/version.txt"
local BLOCKED_PROGS = { lua=true, shell=true, multishell=true, pastebin=true }

os.pullEvent = os.pullEventRaw
local NATIVE_COLOR = term.isColor()

local C = { bg=colors.black, barbg=colors.blue, text=colors.white, dim=colors.lightGray,
            dark=colors.gray, accent=colors.cyan, good=colors.lime, bad=colors.red }

local W, H
local CONFIG, CURRENT, signal, updateAvailable
local windows, focused, desktopIcons, startOpen, menuItems
local drawChrome, drawClock, drawDesktop, drawContent, drawStartMenu
local focus, minimizeWindow, closeRec, launch, initialResume, resumeWith
local handleTitlebarClick, handleTaskbarClick, handleDesktopClick, handleStartClick

local function writeAt(x,y,s,fg,bg)
  term.setCursorPos(x,y)
  if fg then term.setTextColor(fg) end
  if bg then term.setBackgroundColor(bg) end
  term.write(s)
end
local function fill(bg) term.setBackgroundColor(bg); term.clear(); term.setCursorPos(1,1) end
local function centerText(y,s,fg,bg)
  local w=term.getSize(); writeAt(math.floor((w-#s)/2)+1, y, s, fg, bg)
end
local function nowStr() local ok,s=pcall(os.date,"%H:%M:%S"); return ok and s or tostring(os.time()) end

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

local function hash(s)
  s="aur0ra$"..(s or "").."$salt"; local h,g=5381,0
  for i=1,#s do h=(h*33+string.byte(s,i))%1000000007 end
  for i=1,#s do g=(g*31+(string.byte(s,i)*7+3))%1000000007 end
  return string.format("%08x",(h*1000003+g)%1000000007)
end
local function loadConfig()
  if fs.exists(CFGPATH) then
    local f=fs.open(CFGPATH,"r")
    if f then local s=f.readAll(); f.close()
      local ok,t=pcall(textutils.unserialize,s); if ok and type(t)=="table" then return t end end
  end
  return nil
end
local function saveConfig(t) fs.makeDir("/.system"); local f=fs.open(CFGPATH,"w"); f.write(textutils.serialize(t)); f.close() end

local function findUser(name)
  for i,u in ipairs(CONFIG.users) do if u.name:lower()==name:lower() then return i,u end end
end
local function currentUserIndex() for i,u in ipairs(CONFIG.users) do if u==CURRENT then return i end end end
local function addUser(name, pass, isAdmin)
  if not name or name=="" or findUser(name) then return false,"exists" end
  table.insert(CONFIG.users, {name=name, hash=(pass and pass~="") and hash(pass) or nil, admin=isAdmin and true or false})
  saveConfig(CONFIG); return true
end
local function removeUser(idx)
  local u=CONFIG.users[idx]; if not u then return false,"no user" end
  if u.admin then local n=0; for _,x in ipairs(CONFIG.users) do if x.admin then n=n+1 end end
    if n<=1 then return false,"last admin" end end
  if CURRENT==u then return false,"self" end
  table.remove(CONFIG.users,idx); saveConfig(CONFIG); return true
end
local function setUserPass(idx, pass)
  local u=CONFIG.users[idx]; if not u then return false end
  u.hash=(pass and pass~="") and hash(pass) or nil; saveConfig(CONFIG); return true
end

local function normPath(p) return fs.combine("/", p or "") end
local function startsWith(p, prefix) return p==prefix or p:sub(1, #prefix+1)==prefix.."/" end
local function isProtected(user, path, write)
  if not user or user.admin then return false end
  local p = normPath(path)
  if startsWith(p, "/.system") then return true end
  if write and (p=="/startup" or p=="/startup.lua") then return true end
  if write then
    for _,fp in ipairs(CONFIG.protected or {}) do if startsWith(p, normPath(fp)) then return true end end
  end
  return false
end
local function makeFsProxy(user)
  local real = fs
  local proxy = {}
  proxy.delete = function(p) if isProtected(user,p,true) then print("Access denied: "..normPath(p)) return end return real.delete(p) end
  proxy.open = function(p,mode) local m=mode or "r"; local w=(m=="w" or m=="a" or m=="wb" or m=="ab")
    if isProtected(user,p,w) or isProtected(user,p,false) then print("Access denied: "..normPath(p)) return end
    return real.open(p,mode) end
  proxy.move = function(a,b) if isProtected(user,a,true) or isProtected(user,b,true) then print("Access denied") return end return real.move(a,b) end
  proxy.copy = function(a,b) if isProtected(user,b,true) then print("Access denied") return end return real.copy(a,b) end
  proxy.makeDir = function(p) if isProtected(user,p,true) then print("Access denied: "..normPath(p)) return end return real.makeDir(p) end
  proxy.list = function(p) if isProtected(user,p,false) then return {} end return real.list(p) end
  proxy.isDir = function(p) if isProtected(user,p,false) then return false end return real.isDir(p) end
  proxy.exists = function(p) if isProtected(user,p,false) then return false end return real.exists(p) end
  return setmetatable(proxy, {__index=function(_,k) return real[k] end})
end
local function makeSandboxEnv(user) return setmetatable({ fs=makeFsProxy(user) }, {__index=_G}) end
local function sandboxRun(line, user)
  local progName = line:match("^%s*(%S+)")
  local rest = line:match("^%s*%S+%s*(.*)$") or ""
  if not progName then return end
  if BLOCKED_PROGS[progName] then print("Blocked: "..progName) return end
  if progName=="cd" then
    local dir = rest:match("%S+") or "/"
    local nd = shell.resolve(dir)
    if isProtected(user, nd, false) then print("Access denied: "..normPath(nd)) return end
    if fs.isDir(nd) then shell.setDir(nd) else print("Not a dir: "..dir) end return
  end
  local path = shell.resolveProgram(progName)
  if not path then print("No such program: "..progName) return end
  if isProtected(user, path, false) then print("Access denied") return end
  local args={}
  for w in rest:gmatch("%S+") do args[#args+1]=w end
  os.run(makeSandboxEnv(user), path, unpack(args))
end

local function mirrorList(targets)
  local prev0=term.current()
  local minW,minH=9999,9999
  for i=1,#targets do term.redirect(targets[i]); local w,h=term.getSize(); if w<minW then minW=w end; if h<minH then minH=h end end
  term.redirect(prev0)
  local m={}
  for _,name in ipairs({"write","blit","setCursorPos","setCursorBlink","setTextColor","setBackgroundColor","clear","clearLine","scroll","setTextScale","setPaletteColor"}) do
    m[name]=function(...)
      local prev=term.current()
      for i=1,#targets do term.redirect(targets[i]); term[name](...) end
      term.redirect(prev)
    end
  end
  m.getSize=function() return minW,minH end
  m.getCursorPos=function() local p=term.current(); term.redirect(targets[1]); local x,y=term.getCursorPos(); term.redirect(p); return x,y end
  m.getCursorBlink=function() local p=term.current(); term.redirect(targets[1]); local b=term.getCursorBlink(); term.redirect(p); return b end
  m.getTextColor=function() local p=term.current(); term.redirect(targets[1]); local c=term.getTextColor(); term.redirect(p); return c end
  m.getBackgroundColor=function() local p=term.current(); term.redirect(targets[1]); local c=term.getBackgroundColor(); term.redirect(p); return c end
  m.isColor=function() return NATIVE_COLOR end
  m.getPaletteColor=function(i) local p=term.current(); term.redirect(targets[1]); local r,g,b=term.getPaletteColor(i); term.redirect(p); return r,g,b end
  return m
end

local function gatherMonitors()
  local r={}
  for _,s in ipairs(peripheral.getNames()) do
    if peripheral.getType(s)=="monitor" then r[#r+1]={side=s, term=peripheral.wrap(s)} end
  end
  return r
end

local function pickMonitors(monitors)
  fill(colors.black)
  centerText(2, OSNAME.." - display setup", C.accent)
  centerText(4, "Choose screens (mirror to both):", C.dim)
  for i,m in ipairs(monitors) do
    local mw,mh=m.term.getSize()
    writeAt(2, 5+i, i..". "..m.side.."  ("..mw.."x"..mh..")", colors.white)
  end
  local by=6+#monitors
  writeAt(2, by,   "Primary monitor (0=computer): ", colors.lightGray)
  term.setCursorPos(2+30, by); term.setTextColor(colors.white); local a=tonumber(read())
  writeAt(2, by+1, "Second  monitor (0=none): ", colors.lightGray)
  term.setCursorPos(2+30, by+1); term.setTextColor(colors.white); local b=tonumber(read())
  CONFIG.mon1 = (a and a>=1 and a<=#monitors) and monitors[a].side or nil
  CONFIG.mon2 = (b and b>=1 and b<=#monitors and monitors[b].side~=CONFIG.mon1) and monitors[b].side or nil
  saveConfig(CONFIG)
end

local function applyDisplay()
  term.redirect(term.native())
  W,H=term.getSize()
  local monitors=gatherMonitors()
  if #monitors==0 then return end
  local function getM(side) for _,m in ipairs(monitors) do if m.side==side then return m end end end
  if not CONFIG.mon1 or not getM(CONFIG.mon1) then return end
  if CONFIG.mon2==CONFIG.mon1 or not getM(CONFIG.mon2) then CONFIG.mon2=nil end
  local targets={term.native()}
  for _,side in ipairs({CONFIG.mon1, CONFIG.mon2}) do
    local m=getM(side)
    if m then local mw,mh=m.term.getSize()
      if mw>=3 and mh>=3 then targets[#targets+1]=m.term
      else m.term.clear(); m.term.setCursorPos(1,1); m.term.write("This monitor is not supported") end
    end
  end
  if #targets>=2 then local mir=mirrorList(targets); term.redirect(mir); W,H=mir.getSize()
  else local m=getM(CONFIG.mon1); if m then term.redirect(m.term); W,H=m.term.getSize() end end
end

local function doUpdate()
  local h=http.get(OS_SOURCE); if not h then return false end
  local b=h.readAll(); h.close()
  if not b or b=="" then return false end
  local f=fs.open("/startup","w"); f.write(b); f.close(); return true
end
local function checkUpdate()
  if VERSION_URL=="" then return end
  local h=http.get(VERSION_URL)
  if h then local v=h.readAll(); h.close(); v=(v or ""):gsub("%s","")
    if v~="" and v~=VERSION then updateAvailable=true end end
end

local LOGO = {
  "      .:::::::::::::::.      ",
  "    .'                 '.    ",
  "   .   A  U  R  O  R  A   .  ",
  "   .         O S          .  ",
  "    '.                 .'    ",
  "      ':::::::::::::::'      ",
}

local function setup()
  fill(colors.black)
  centerText(math.floor(H/2)-3, OSNAME.." - first setup", C.accent)
  centerText(math.floor(H/2)-1, "Create an admin account.", C.dim)
  local y=math.floor(H/2)+1
  writeAt(4,y, "Admin name: ",C.text); local user=read(); user=(user and user~="") and user or "admin"
  writeAt(4,y+2,"Password (empty = none): ",C.text); local p=readMasked()
  CONFIG={mode="gui", accent=ACCENTS[1], users={{name=user, hash=(p and p~="") and hash(p) or nil, admin=true}}, rn_target=16, protected={}}
  saveConfig(CONFIG); centerText(y+5,"Saved! Starting...",C.good); sleep(1)
end

local function bootGate()
  fill(colors.black)
  centerText(math.floor(H/2)-1, OSNAME.." v"..VERSION, C.accent)
  centerText(math.floor(H/2)+1, "[M] monitors   [R] recovery   else boot...", C.dim)
  local t=os.startTimer(2)
  while true do
    local ev,p1=os.pullEvent()
    if ev=="key" and p1==keys.m then
      term.redirect(term.native()); W,H=term.getSize()
      local monitors=gatherMonitors()
      if #monitors>=1 then pickMonitors(monitors) end
      applyDisplay(); return
    elseif ev=="key" and p1==keys.r then
      fill(colors.black); centerText(math.floor(H/2)-1, "Recovery - admin password", C.accent)
      writeAt(2, math.floor(H/2)+1, "Password: ", C.text)
      term.setCursorPos(12, math.floor(H/2)+1); term.setTextColor(C.text); term.setBackgroundColor(colors.black)
      local pw=readMasked()
      local ok=false
      for _,u in ipairs(CONFIG.users) do if u.admin and u.hash and hash(pw or "")==u.hash then ok=true break end end
      if ok then
        fill(colors.black); term.setCursorPos(1,1)
        print("Recovery shell. 'rm /.system/config' to reset users.")
        print("Type 'exit' to return to OS.")
        shell.run("shell")
      else centerText(math.floor(H/2)+3, "Access denied", C.bad); sleep(1) end
      return
    elseif ev=="timer" and p1==t then return end
  end
end

local function boot()
  local steps={"Loading kernel...","Mounting filesystem...","Starting services...","Starting network...","Loading desktop..."}
  local barW=math.min(36, W-10); local bx=math.floor((W-barW)/2)+1; local by=H-3
  local logoY=math.floor(H/2)-4
  local maxLen=0; for _,l in ipairs(LOGO) do maxLen=math.max(maxLen,#l) end
  for phase=1,#steps do
    fill(colors.black)
    local col=ACCENTS[((phase-1)%#ACCENTS)+1]
    for i,l in ipairs(LOGO) do centerText(logoY+i-1, l..string.rep(" ",maxLen-#l), col, colors.black) end
    centerText(logoY+#LOGO+1, OSNAME.." v"..VERSION, colors.white, colors.black)
    centerText(by-3, steps[phase], colors.lightGray, colors.black)
    paintutils.drawBox(bx-1, by-1, bx+barW, by+1, col)
    local fw=math.floor(barW*phase/#steps)
    if fw>0 then paintutils.drawFilledBox(bx, by, bx+fw-1, by, col) end
    sleep(0.3)
  end
  sleep(0.2)
end

local function login()
  while true do
    fill(C.bg)
    local maxLen=0; for _,l in ipairs(LOGO) do maxLen=math.max(maxLen,#l) end
    for i,l in ipairs(LOGO) do centerText(1+i, l..string.rep(" ",maxLen-#l), C.accent, C.bg) end
    local baseY=1+#LOGO+1
    centerText(baseY, OSNAME.." v"..VERSION, C.dim, C.bg)
    if updateAvailable then centerText(baseY+1, "* update available *", C.good, C.bg) end
    centerText(baseY+3, "Select user:", C.text, C.bg)
    for i,u in ipairs(CONFIG.users) do
      local label=i..". "..u.name..(u.admin and " (admin)" or "")..(u.hash and "" or " [no pass]")
      centerText(baseY+4+i, label, C.text, C.bg)
    end
    writeAt(2, H-1, string.rep(" ", W-2), nil, C.bg)
    writeAt(2, H-1, "> Number or name: ", C.accent, C.bg)
    term.setTextColor(C.text); term.setBackgroundColor(C.bg); local inp=read()
    local idx=tonumber(inp); local u=idx and CONFIG.users[idx] or nil
    if not u then for _,x in ipairs(CONFIG.users) do if x.name:lower()==(inp or ""):lower() then u=x break end end end
    if not u then centerText(H, "No such user", C.bad, C.bg); sleep(0.8)
    elseif u.hash then
      writeAt(2, H-1, string.rep(" ", W-2), nil, C.bg)
      writeAt(2, H-1, "Password for "..u.name..": ", C.accent, C.bg)
      term.setTextColor(C.text); term.setBackgroundColor(C.bg); local pass=readMasked()
      if hash(pass or "")~=u.hash then centerText(H,"Wrong password",C.bad,C.bg); sleep(0.8)
      else CURRENT=u; return end
    else CURRENT=u; return end
  end
end

local function makeAPI(rec)
  local surf=rec.surf
  local aw,ah=surf.getSize()
  local api={W=aw,H=ah,win=surf}
  api.clear=function(bg) surf.setBackgroundColor(bg or colors.black); surf.clear(); surf.setCursorPos(1,1) end
  api.write=function(x,y,s,fg,bg) surf.setCursorPos(x,y); if fg then surf.setTextColor(fg) end; if bg then surf.setBackgroundColor(bg) end; surf.write(s) end
  api.fill=function(bg) surf.setBackgroundColor(bg or colors.black); surf.clear() end
  api.center=function(y,s,fg,bg) surf.setCursorPos(math.floor((aw-#s)/2)+1,y); if fg then surf.setTextColor(fg) end; if bg then surf.setBackgroundColor(bg) end; surf.write(s) end
  api.setCursor=function(x,y) surf.setCursorPos(x,y) end
  api.color=function(fg,bg) if fg then surf.setTextColor(fg) end; if bg then surf.setBackgroundColor(bg) end end
  api.box=function(x1,y1,x2,y2,bgCol,frameCol)
    if bgCol then surf.setBackgroundColor(bgCol); for yy=y1,y2 do surf.setCursorPos(x1,yy); surf.write(string.rep(" ",x2-x1+1)) end end
    if frameCol then surf.setBackgroundColor(colors.black); surf.setTextColor(frameCol)
      surf.setCursorPos(x1,y1); surf.write(string.rep("-",x2-x1+1)); surf.setCursorPos(x1,y2); surf.write(string.rep("-",x2-x1+1))
      for yy=y1,y2 do surf.setCursorPos(x1,yy); surf.write("|"); surf.setCursorPos(x2,yy); surf.write("|") end end
  end
  api.rawprint=function(...) local p=term.redirect(surf); print(...); term.redirect(p) end
  api.readline=function()
    local s=""
    while true do local ev,a=api.pull()
      if ev=="char" then s=s..a; surf.write(a)
      elseif ev=="key" and a==keys.enter then api.rawprint(); return s
      elseif ev=="key" and a==keys.backspace and #s>0 then s=s:sub(1,#s-1); local x,y=surf.getCursorPos(); surf.setCursorPos(x-1,y); surf.write(" "); surf.setCursorPos(x-1,y) end
    end
  end
  api.input=function(x,y,prompt,masked,width)
    width=width or 20
    api.write(x,y,prompt, colors.lightGray, nil); local cx=x+#prompt; local s=""
    local function redraw() local sh=masked and string.rep("*",#s) or s
      surf.setTextColor(colors.white); surf.setCursorPos(cx,y); surf.write(sh..string.rep(" ",width-#sh)); surf.setCursorPos(cx+#sh,y) end
    redraw()
    while true do local ev,a=api.pull()
      if ev=="char" and #s<width then s=s..a; redraw()
      elseif ev=="key" and a==keys.enter then surf.setCursorPos(cx,y); surf.write((masked and string.rep("*",#s) or s)..string.rep(" ",width-#s)); return s
      elseif ev=="key" and a==keys.backspace and #s>0 then s=s:sub(1,#s-1); redraw() end
    end
  end
  api.pull=function(filter) return coroutine.yield(filter) end
  api.title=function(s) rec.title=s; if drawChrome then drawChrome() end end
  api.minimize=function() if minimizeWindow then minimizeWindow(rec) end end
  api.close=function() rec.dead=true end
  return api
end

local appTerminal, appFiles, appSettings, appUsers, appSecurity, appRednet, appAbout, appUpdate

appTerminal = function(api)
  api.title("Terminal")
  api.clear(C.bg); api.win.setCursorPos(1,1); api.win.setTextColor(colors.white)
  api.rawprint(OSNAME.." terminal. 'exit' close | 'bg' minimize")
  if not CURRENT.admin then api.rawprint("(sandboxed: startup and /.system are protected)") end
  while true do
    api.color(C.accent); api.rawprint(CURRENT.name..(CURRENT.admin and "#" or "$").." "..shell.dir().."> "); api.color(colors.white)
    local line=api.readline()
    if not line then line="" end
    local low=(line:match("^%s*(%S+)") or ""):lower()
    if low=="exit" then api.close(); return
    elseif low=="bg" then api.minimize()
    elseif low=="update" then appUpdate(api)
    elseif low=="lock" then signal="lock"; api.close(); return
    elseif low=="clear" then api.clear(C.bg); api.win.setCursorPos(1,1)
    elseif low=="help" then api.rawprint("exit bg update lock clear help + CC cmds")
    elseif line:match("%S") then
      local p=term.redirect(api.win)
      if CURRENT.admin then shell.run(line) else sandboxRun(line, CURRENT) end
      term.redirect(p)
    end
  end
end

appFiles = function(api)
  api.title("Files")
  local path,sel="/",1
  local list=fs.list(path) or {}; table.sort(list); sel=math.max(1,math.min(sel,#list))
  while true do
    api.clear(C.bg)
    api.write(1,1,"Files: "..path, C.accent); api.write(1,2,"Enter:open BS:up E:edit Esc:close", C.dim)
    for i,name in ipairs(list) do
      local y=2+i; if y>api.H then break end
      local full=fs.combine(path,name); local isDir=fs.isDir(full)
      if i==sel then api.write(1,y,"> "..name..(isDir and "/" or " ")..string.rep(" ",api.W), C.bg, C.accent)
      else api.write(1,y,"  "..name..(isDir and "/" or " "), isDir and C.accent or colors.white) end
    end
    local ev,a,b,c=api.pull()
    if ev=="key" then
      if a==keys.up then sel=math.max(1,sel-1)
      elseif a==keys.down then sel=math.min(#list,sel+1)
      elseif a==keys.enter then local nm=list[sel]; if nm then local full=fs.combine(path,nm)
        if fs.isDir(full) then path=full; list=fs.list(path) or {}; table.sort(list); sel=1
        else local p=term.redirect(api.win); if CURRENT.admin then shell.run("edit",full) else sandboxRun("edit "..full, CURRENT) end; term.redirect(p) end end
      elseif a==keys.backspace and path~="/" then path=fs.getDir(path); list=fs.list(path) or {}; table.sort(list); sel=1
      elseif a==keys.e then local nm=list[sel]; if nm then local p=term.redirect(api.win); if CURRENT.admin then shell.run("edit",fs.combine(path,nm)) else sandboxRun("edit "..fs.combine(path,nm), CURRENT) end; term.redirect(p) end
      elseif a==keys.esc then api.close(); return end
    elseif ev=="mouse_click" or ev=="monitor_touch" then
      if c==1 and b>=api.W-1 then api.close(); return end
      if c>=3 then local idx=c-2; if idx>=1 and idx<=#list then sel=idx end end
    end
  end
end

appSettings = function(api)
  api.title("Settings")
  while true do
    api.clear(C.bg)
    api.write(2,2,"[1] Change my password", colors.white)
    api.write(2,3,"[2] Accent color", colors.white)
    api.write(2,4,"[3] My name", colors.white)
    api.write(2,6,"User: "..CURRENT.name..(CURRENT.admin and " (admin)" or ""), C.dim)
    api.write(2,7,OSNAME.." v"..VERSION, C.dim)
    api.write(2,api.H,"[Esc] close", C.dim)
    local ev,a,b,c=api.pull()
    if ev=="char" and a=="1" then
      api.box(2,api.H-6,api.W-1,api.H-2,colors.black,C.accent)
      api.write(4,api.H-5,"Old password: ",colors.white); local old=api.input(4+14,api.H-5,"",false,16)
      if CURRENT.hash and hash(old or "")~=CURRENT.hash then api.write(4,api.H-3,"Wrong password.",C.bad); api.pull()
      else api.write(4,api.H-4,"New (empty=remove): ",colors.white); local n1=api.input(4+20,api.H-4,"",true,16)
        setUserPass(currentUserIndex(), n1); api.write(4,api.H-3,"Saved!",C.good); api.pull() end
    elseif ev=="char" and a=="2" then
      local i=1; for k,x in ipairs(ACCENTS) do if x==CONFIG.accent then i=k end end
      CONFIG.accent=ACCENTS[i%#ACCENTS+1]; C.accent=CONFIG.accent; saveConfig(CONFIG)
      api.write(2,9,"Accent changed.",C.good); api.pull()
    elseif ev=="char" and a=="3" then
      api.write(2,api.H-3,"New name: ",colors.white); local u=api.input(2+10,api.H-3,"",false,16)
      if u and u~="" and not findUser(u) then CURRENT.name=u; saveConfig(CONFIG); api.write(2,api.H-2,"Saved!",C.good); api.pull() end
    elseif (ev=="key" and a==keys.esc) then api.close(); return
    elseif (ev=="mouse_click" or ev=="monitor_touch") and c==1 and b>=api.W-1 then api.close(); return end
  end
end

appUsers = function(api)
  api.title("Users")
  if not (CURRENT and CURRENT.admin) then api.clear(C.bg); api.write(2,2,"Admin only.",C.bad); api.write(2,4,"[Esc] back",C.dim)
    while true do local ev,a=api.pull(); if ev=="key" and a==keys.esc then api.close(); return end end end
  while true do
    api.clear(C.bg)
    api.write(2,1,string.format("%-3s %-12s %-6s %-4s","#","name","role","pass"),C.dim)
    for i,u in ipairs(CONFIG.users) do api.write(2,1+i,string.format("%-3d %-12s %-6s %-4s",i,u.name,u.admin and "admin" or "user",u.hash and "yes" or "no"),colors.white) end
    local oy=2+#CONFIG.users+2
    api.write(2,oy,"[a] add user  [d] add admin  [r] remove  [p] pass", colors.white)
    api.write(2,api.H,"[Esc] close", C.dim)
    local ev,a,b,c=api.pull()
    if ev=="char" and (a=="a" or a=="d") then
      local isAdmin = (a=="d")
      api.write(2,oy+2,"Name: ",colors.white); local name=api.input(2+6,oy+2,"",false,16)
      if name and name~="" and not findUser(name) then api.write(2,oy+3,"Pass(empty=none): ",colors.white); local p=api.input(2+18,oy+3,"",true,12); addUser(name,p,isAdmin); api.write(2,oy+4,isAdmin and "Admin added." or "User added.",C.good); api.pull() end
    elseif ev=="char" and a=="r" then api.write(2,oy+2,"Number: ",colors.white); local n=tonumber(api.input(2+8,oy+2,"",false,8)); local ok,err=removeUser(n); api.write(2,oy+3,ok and "Removed." or ("Err: "..tostring(err)),C.dim); api.pull()
    elseif ev=="char" and a=="p" then api.write(2,oy+2,"Number: ",colors.white); local n=tonumber(api.input(2+8,oy+2,"",false,8)); local u=CONFIG.users[n]
      if u then api.write(2,oy+3,"Pass(empty=remove): ",colors.white); local p=api.input(2+20,oy+3,"",true,12); setUserPass(n,p); api.write(2,oy+4,"Done.",C.good); api.pull() end
    elseif (ev=="key" and a==keys.esc) then api.close(); return
    elseif (ev=="mouse_click" or ev=="monitor_touch") and c==1 and b>=api.W-1 then api.close(); return end
  end
end

appSecurity = function(api)
  api.title("Security")
  if not (CURRENT and CURRENT.admin) then api.clear(C.bg); api.write(2,2,"Admin only.",C.bad); api.write(2,4,"[Esc] back",C.dim)
    while true do local ev,a=api.pull(); if ev=="key" and a==keys.esc then api.close(); return end end end
  CONFIG.protected = CONFIG.protected or {}
  while true do
    api.clear(C.bg)
    api.write(2,1,"Protected folders (non-admins can't write):", C.accent)
    api.write(2,2,"startup and /.system are always protected", C.dim)
    for i,p in ipairs(CONFIG.protected) do api.write(2,2+i, i..". "..p, colors.white) end
    local oy=3+#CONFIG.protected+1
    api.write(2,oy,"[a] add path  [r] remove", colors.white)
    api.write(2,api.H,"[Esc] close", C.dim)
    local ev,a,b,c=api.pull()
    if ev=="char" and a=="a" then
      api.write(2,oy+2,"Path: ",colors.white); local p=api.input(2+6,oy+2,"",false,20)
      if p and p~="" then table.insert(CONFIG.protected, normPath(p)); saveConfig(CONFIG); api.write(2,oy+3,"Added.",C.good); api.pull() end
    elseif ev=="char" and a=="r" then
      api.write(2,oy+2,"Number: ",colors.white); local n=tonumber(api.input(2+8,oy+2,"",false,8))
      if n and CONFIG.protected[n] then table.remove(CONFIG.protected,n); saveConfig(CONFIG); api.write(2,oy+3,"Removed.",C.good); api.pull() end
    elseif (ev=="key" and a==keys.esc) then api.close(); return
    elseif (ev=="mouse_click" or ev=="monitor_touch") and c==1 and b>=api.W-1 then api.close(); return end
  end
end

appRednet = function(api)
  api.title("Rednet")
  local target=CONFIG.rn_target or 16
  local status="Ready."
  local function sendToggle(mode)
    local m=peripheral.find("modem"); if not m then return false,"No modem" end
    m.open(ACK); m.transmit(CTRL,ACK,SECRET..":"..mode); local t=os.startTimer(2)
    while true do local ev,p1,p2,pp4,p5=api.pull()
      if ev=="modem_message" and p2==ACK and type(p5)=="string" and p5:sub(1,#SECRET)==SECRET then return true,p5
      elseif ev=="timer" and p1==t then return false,"No reply (off/offline)" end end
  end
  while true do
    api.clear(C.bg)
    api.write(2,2,"Target: computer #"..target, C.accent)
    api.write(2,4,"[1] Disable target (off)", colors.white)
    api.write(2,5,"[2] Enable target (on)", colors.white)
    api.write(2,6,"[3] Change target", colors.white)
    api.write(2,8,status, C.dim); api.write(2,api.H,"[Esc] close", C.dim)
    local ev,a,b,c=api.pull()
    if ev=="char" then
      if a=="1" then local ok,r=sendToggle("OFF"); status=(ok and "OFF -> " or "")..tostring(r)
      elseif a=="2" then local ok,r=sendToggle("ON"); status=(ok and "ON -> " or "")..tostring(r)
      elseif a=="3" then api.write(2,10,"Target ID: ",colors.white); local v=tonumber(api.input(2+11,10,"",false,8))
        if v then target=v; CONFIG.rn_target=v; saveConfig(CONFIG); status="Target: "..v end end
    elseif (ev=="key" and a==keys.esc) then api.close(); return
    elseif (ev=="mouse_click" or ev=="monitor_touch") and c==1 and b>=api.W-1 then api.close(); return end
  end
end

appAbout = function(api)
  api.title("About")
  api.clear(C.bg)
  api.center(2, OSNAME.." v"..VERSION, C.accent)
  api.center(4, "User: "..CURRENT.name..(CURRENT.admin and " (admin)" or ""), colors.white)
  api.center(5, "Computer #"..os.getComputerID(), C.dim)
  api.center(6, "Accounts: "..#CONFIG.users, C.dim)
  if updateAvailable then api.center(7, "* update available *", C.good) end
  api.center(api.H, "[Esc] close", C.dim)
  while true do local ev,a,b,c=api.pull()
    if (ev=="key" and a==keys.esc) or ((ev=="mouse_click" or ev=="monitor_touch") and c==1 and b>=api.W-1) then api.close(); return end end
end

appUpdate = function(api)
  api.title("Update")
  api.clear(C.bg)
  api.center(2, "SYSTEM UPDATE", C.accent)
  api.center(4, "Current version: "..VERSION, colors.white)
  api.center(6, "Re-download the OS and reboot?", colors.lightGray)
  api.center(8, "[Y] yes   [N] no", colors.white)
  while true do
    local ev,a=api.pull()
    if ev=="char" and (a=="y" or a=="Y") then
      api.center(10,"Downloading...", C.accent)
      local ok=pcall(doUpdate)
      api.center(11, ok and "Done. Rebooting." or "Failed (HTTP off?).", ok and C.good or C.bad)
      sleep(1.2); if ok then signal="reboot" end; api.close(); return
    elseif ev=="char" and (a=="n" or a=="N") then api.close(); return end
  end
end

local function appList()
  local t={
    {name="Terminal", glyph=">", col=colors.green, fn=appTerminal},
    {name="Files", glyph="F", col=colors.lightBlue, fn=appFiles},
    {name="Settings", glyph="S", col=colors.purple, fn=appSettings},
    {name="Users", glyph="U", col=colors.pink, fn=appUsers, admin=true},
    {name="Security", glyph="!", col=colors.red, fn=appSecurity, admin=true},
    {name="Rednet", glyph="N", col=colors.cyan, fn=appRednet},
    {name="About", glyph="i", col=colors.yellow, fn=appAbout},
    {name="Update", glyph="^", col=colors.lime, fn=appUpdate},
  }
  if fs.isDir("/apps") then
    for _,f in ipairs(fs.list("/apps")) do
      if f:sub(-4)==".lua" then local nm=f:gsub("%.lua$","")
        table.insert(t,{name=nm, glyph=nm:sub(1,1):upper(), col=colors.gray, user="/apps/"..f}) end
    end
  end
  return t
end

initialResume = function(rec)
  if rec.dead then return end
  local ok,filt=coroutine.resume(rec.co)
  if not ok then rec.dead=true; rec.err=tostring(filt) else rec.filter=filt end
  if coroutine.status(rec.co)=="dead" then rec.dead=true end
end
resumeWith = function(rec, event)
  if rec.dead then return end
  if rec.filter and event[1]~=rec.filter then return end
  local ok,filt=coroutine.resume(rec.co, unpack(event))
  if not ok then rec.dead=true; rec.err=tostring(filt) else rec.filter=filt end
  if coroutine.status(rec.co)=="dead" then closeRec(rec) end
end

focus = function(rec)
  if focused==rec then return end
  if focused and not focused.dead then focused.surf.setVisible(false) end
  focused=rec; rec.minimized=false; rec.surf.setVisible(true); rec.surf.redraw(); drawChrome()
end
minimizeWindow = function(rec)
  rec.minimized=true
  if focused==rec then
    rec.surf.setVisible(false); focused=nil
    for i=#windows,1,-1 do if not windows[i].dead and not windows[i].minimized then focus(windows[i]); return end end
    drawChrome(); drawDesktop()
  end
end
closeRec = function(rec)
  rec.dead=true
  for i=#windows,1,-1 do if windows[i]==rec then table.remove(windows,i) break end end
  if focused==rec then
    focused=nil
    for i=#windows,1,-1 do if not windows[i].dead then focus(windows[i]); return end end
    drawChrome(); drawDesktop()
  end
end

launch = function(entry)
  if #windows>=12 then return end
  local surf=window.create(term.current(),1,2,W,H-2)
  surf.setVisible(false)
  local rec={surf=surf, minimized=false, dead=false, title=entry.name, entry=entry}
  rec.api=makeAPI(rec)
  if entry.fn then
    rec.co=coroutine.create(function() entry.fn(rec.api) end)
  elseif entry.user then
    local title=entry.name
    local gf=fs.open(entry.user,"r")
    if gf then
      local src=gf.readAll(); gf.close()
      local DQ=string.char(34); local SQ=string.char(39)
      local pn=src:match("program_name%s*=%s*"..DQ.."([^"..DQ.."]+)"..DQ) or src:match("program_name%s*=%s*"..SQ.."([^"..SQ.."]+)"..SQ)
      if pn then title=pn end
    end
    rec.title=title
    local fn,err=loadfile(entry.user)
    if not fn then rec.co=coroutine.create(function(a) a.clear(colors.red); a.write(1,1,"load err: "..tostring(err),colors.white); a.pull() end)
    else rec.co=coroutine.create(function()
      local env=setmetatable({api=rec.api, program_name=title, colors=colors, keys=keys, term=surf, fs=fs, http=http,
        string=string, math=math, table=table, tostring=tostring, tonumber=tonumber, type=type,
        print=function(...) local p=term.redirect(surf); print(...); term.redirect(p) end,
        write=function(...) local p=term.redirect(surf); term.write(...); term.redirect(p) end}, {__index=_G})
      setfenv(fn,env); fn() end) end
  end
  table.insert(windows,rec); initialResume(rec); focus(rec); return rec
end

drawClock = function() writeAt(math.max(1,W-8), H, nowStr(), colors.white, C.dark) end
drawChrome = function()
  paintutils.drawFilledBox(1,1,W,1,C.barbg)
  if focused then
    writeAt(2,1," "..focused.title, colors.white, C.barbg)
    if W>=8 then writeAt(W-5,1,"[_]", colors.yellow, C.barbg); writeAt(W-2,1,"[X]", colors.red, C.barbg) end
  else
    writeAt(2,1," "..OSNAME.." v"..VERSION, C.accent, C.barbg)
  end
  paintutils.drawFilledBox(1,H,W,H,C.dark)
  writeAt(1,H,"MENU", colors.white, C.accent)
  local bx=6
  for _,rec in ipairs(windows) do
    if not rec.dead and bx<W-16 then
      local lab=(rec==focused and "[" or " ")..rec.title..(rec==focused and "]" or " ")
      if #lab>12 then lab=lab:sub(1,12) end
      writeAt(bx,H,lab, colors.white, rec==focused and C.accent or C.dark)
      rec._tbX,rec._tbW=bx,#lab; bx=bx+#lab+1
    end
  end
  if updateAvailable and W>=22 then writeAt(W-16,H,"UPDATE", C.good, C.dark) end
  drawClock()
end
drawDesktop = function()
  desktopIcons={}
  paintutils.drawFilledBox(1,2,W,H-1,C.bg)
  if H>=5 then centerText(3, OSNAME, C.accent); centerText(4, "user: "..CURRENT.name..(CURRENT.admin and " (admin)" or ""), C.dim) end
  if updateAvailable and H>=6 then centerText(5, "* update available *", C.good) end
  local apps=appList()
  local cols=math.max(1, math.floor(W/12))
  local iw,ih,gx,gy=7,3,2,1
  local sx=math.floor((W-(cols*iw+(cols-1)*gx))/2)+1
  local sy=7
  for _,e in ipairs(apps) do
    if not(e.admin and not (CURRENT and CURRENT.admin)) then
      local r=math.floor(#desktopIcons/cols); local c=#desktopIcons%cols
      local x=sx+c*(iw+gx); local y=sy+r*(ih+gy+1)
      if y+ih>H-1 then break end
      paintutils.drawFilledBox(x,y,x+iw-1,y+ih-1, e.col or colors.gray)
      paintutils.drawBox(x,y,x+iw-1,y+ih-1, colors.white)
      writeAt(x+math.floor(iw/2), y+1, e.glyph or "?", colors.white, e.col or colors.gray)
      local nm=e.name; if #nm>iw then nm=nm:sub(1,iw) end
      writeAt(math.max(1,x+math.floor((iw-#nm)/2)), y+ih, nm, colors.white)
      table.insert(desktopIcons,{entry=e,x=x,y=y,w=iw,h=ih})
    end
  end
end
drawStartMenu = function()
  local apps=appList()
  local items={}
  for _,e in ipairs(apps) do if not(e.admin and not (CURRENT and CURRENT.admin)) then items[#items+1]=e end end
  items[#items+1]={name="-- Lock --", act="lock"}
  items[#items+1]={name="-- Reboot --", act="reboot"}
  items[#items+1]={name="-- Shut --", act="shutdown"}
  local mw=16; local mh=math.min(#items+2, H-3); local my=H-1-mh
  paintutils.drawFilledBox(1,my,mw,H-1, colors.black); paintutils.drawBox(1,my,mw,H-1, C.accent)
  writeAt(2,my,"MENU", C.accent, colors.black); menuItems={}
  local yy=my+1
  for _,e in ipairs(items) do writeAt(2,yy,e.name, colors.white, colors.black); menuItems[yy]=e; yy=yy+1 end
  startOpen=true
end
drawContent = function()
  drawChrome()
  if not focused then drawDesktop() end
end

handleTitlebarClick = function(x)
  if not focused then return end
  if x>=W-2 and W>=8 then closeRec(focused)
  elseif x>=W-5 and x<W-2 and W>=8 then minimizeWindow(focused) end
end
handleTaskbarClick = function(x)
  if x<=4 then if startOpen then startOpen=false; drawContent() else drawStartMenu() end return end
  if updateAvailable and W>=22 and x>=W-16 and x<=W-11 then launch({name="Update",fn=appUpdate}); return end
  for _,rec in ipairs(windows) do
    if not rec.dead and rec._tbX and x>=rec._tbX and x<rec._tbX+(rec._tbW or 1) then
      if focused==rec then minimizeWindow(rec) else focus(rec) end; return end
  end
end
handleDesktopClick = function(x,y)
  for _,ic in ipairs(desktopIcons) do
    if x>=ic.x and x<ic.x+ic.w and y>=ic.y and y<ic.y+ic.h then launch(ic.entry); return end
  end
end
handleStartClick = function(x,y)
  local it=menuItems[y]; startOpen=false
  if it then
    if it.act=="lock" then signal="lock"
    elseif it.act=="reboot" then signal="reboot"
    elseif it.act=="shutdown" then signal="shutdown"
    elseif it.fn or it.user then launch(it) end
  end
  drawContent()
end

local function wm()
  signal=nil; windows={}; focused=nil; desktopIcons={}; startOpen=false; menuItems={}
  drawChrome(); drawDesktop()
  local clk=os.startTimer(1)
  while true do
    local event={os.pullEventRaw()}; local ev=event[1]
    if signal then return signal end
    if ev=="timer" and event[2]==clk then drawClock(); clk=os.startTimer(1)
    elseif ev=="mouse_click" or ev=="monitor_touch" then
      local x,y=event[3],event[4]
      if startOpen then handleStartClick(x,y)
      elseif y==H then handleTaskbarClick(x)
      elseif y==1 then handleTitlebarClick(x)
      elseif focused then resumeWith(focused,{ev,event[2],event[3],event[4]-1})
      else handleDesktopClick(x,y) end
    elseif ev=="key" or ev=="char" or ev=="paste" then
      if focused then resumeWith(focused,event) end
    else
      for _,rec in ipairs(windows) do resumeWith(rec,event) end
    end
    if signal then return signal end
  end
end

local function main()
  CONFIG=loadConfig() or {users={}}
  if not CONFIG.users or #CONFIG.users==0 then
    term.redirect(term.native()); W,H=term.getSize()
    setup()
  end
  applyDisplay()
  if not NATIVE_COLOR then fill(colors.black); print(OSNAME.." needs an advanced (color) computer."); sleep(2) end
  C.accent=CONFIG.accent or colors.cyan
  bootGate(); boot(); pcall(checkUpdate)
  while true do
    login()
    local r=wm()
    if r=="reboot" then os.reboot()
    elseif r=="shutdown" then os.shutdown() end
  end
end

main()
