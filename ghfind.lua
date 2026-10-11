#!/usr/bin/env lua
local _=string.byte
local WS = package.config:sub(1,1)=="\\" and "\\" or "/"

local function J(x)
  local p=1
  local function uc(cp)
    if cp<0x80 then return string.char(cp) end
    if cp<0x800 then return string.char(0xC0+cp//0x40,0x80+cp%0x40) end
    if cp<0x10000 then
      return string.char(0xE0+cp//0x1000,0x80+cp//0x40%0x40,0x80+cp%0x40)
    end
    return string.char(0xF0+cp//0x40000,0x80+cp//0x1000%0x40,
                       0x80+cp//0x40%0x40,0x80+cp%0x40)
  end
  local function sk() while x:sub(p,p):match("[ \t\r\n]") do p=p+1 end end
  local pv
  local function ps()
    p=p+1 local t={}
    while true do
      local c=x:sub(p,p)
      if c=="" then error("json") end
      if c=='"' then p=p+1 break end
      if c=="\\" then
        local e=x:sub(p+1,p+1) p=p+2
        t[#t+1]=(e=="n" and "\n") or (e=="t" and "\t") or
                (e=="r" and "\r") or e
        if e=="u" then
          local cp=tonumber(x:sub(p,p+3),16) or 63 p=p+4
          if cp>=0xD800 and cp<=0xDBFF and x:sub(p,p+1)=="\\u" then
            local lo=tonumber(x:sub(p+2,p+5),16)
            if lo and lo>=0xDC00 and lo<=0xDFFF then
              cp=0x10000+(cp-0xD800)*0x400+(lo-0xDC00) p=p+6
            end
          end
          t[#t]=uc(cp)
        end
      else t[#t+1]=c p=p+1 end
    end
    return table.concat(t)
  end
  local function pn()
    local s=x:match("^-?%d+%.?%d*[eE]?[-+]?%d*",p)
    p=p+#s return tonumber(s)
  end
  local function po()
    p=p+1 local o={} sk()
    if x:sub(p,p)=="}" then p=p+1 return o end
    while true do
      sk() local k=ps() sk() p=p+1 sk()
      o[k]=pv() sk()
      local c=x:sub(p,p) p=p+1
      if c=="}" then break end
      if c~="," then error("@json "..p) end
    end
    return o
  end
  local function pa()
    p=p+1 local a={} sk()
    if x:sub(p,p)=="]" then p=p+1 return a end
    while true do
      a[#a+1]=pv() sk()
      local c=x:sub(p,p) p=p+1
      if c=="]" then break end
      if c~="," then error("@arr "..p) end
    end
    return a
  end
  pv=function()
    sk() local c=x:sub(p,p)
    if c=="{" then return po() end
    if c=="[" then return pa() end
    if c=='"' then return ps() end
    if c=="t" then p=p+4 return true end
    if c=="f" then p=p+5 return false end
    if c=="n" then p=p+4 return nil end
    return pn()
  end
  return pv()
end

local C=(os.getenv("NO_COLOR")==nil) and (os.getenv("TERM")~="dumb")
local function g(s,k)
  k=k or "0" return C and ("\27["..k.."m"..tostring(s).."\27[0m") or tostring(s)
end
local function sh(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function ue(s) return (tostring(s):gsub("[^%w%-%.%_%~]",function(c)
  return string.format("%%%02X",_(c)) end)) end
local function nb(n)
  n=tonumber(n) or 0
  if n>=1e6 then return ("%.1fM"):format(n/1e6) end
  if n>=1e3 then return ("%.1fk"):format(n/1e3) end
  return tostring(n//1)
end
local function pad(s,n)
  s=tostring(s) if #s>=n then return s:sub(1,n-1).."…" end
  return s..string.rep(" ",n-#s)
end

local function home() return os.getenv("HOME") or os.getenv("USERPROFILE") or "." end
local function cdir()
  local x=os.getenv("XDG_CACHE_HOME") or (home()..WS..".cache")
  return x..WS.."ghfind"
end
local function mkp(p)
  if WS=="\\" then os.execute('if not exist "'..p..'" mkdir "'..p..'" >nul 2>nul')
  else os.execute("mkdir -p "..sh(p).." 2>/dev/null") end
end
local function hsh(s)
  local h=5381 for i=1,#s do h=(h*33+s:byte(i))%0xFFFFFFFF end
  return ("%08x"):format(h)
end

local function cfg_path() return home()..WS..".config"..WS.."ghfind"..WS.."config.lua" end

local function load_cfg()
  local f=io.open(cfg_path(),"r")
  if not f then return {} end
  local s=f:read("*a") f:close()
  local fn=loadstring or load
  local ok,r=pcall(fn,"return "..s)
  if ok and type(r)=="table" then return r end
  return {}
end
local function save_cfg(c)
  local d=cfg_path():match("^(.*)"..WS.."[^"..WS.."]+$")
  if d then mkp(d) end
  local f=io.open(cfg_path(),"w")
  if not f then return end
  f:write("{\n")
  for k,v in pairs(c) do
    if type(v)=="string" then f:write(("  %s=%q,\n"):format(k,v))
    elseif type(v)=="number" or type(v)=="boolean" then
      f:write(("  %s=%s,\n"):format(k,tostring(v)))
    end
  end
  f:write("}\n") f:close()
end

local function ld_seen(k)
  local p=cdir()..WS..hsh(k)..".seen"
  local s={} local f=io.open(p,"r")
  if f then for l in f:lines() do if #l>0 then s[l]=true end end f:close() end
  return s,p
end
local function sv_seen(s,p)
  mkp(cdir()) local f=io.open(p,"w")
  if not f then return end
  for k in pairs(s) do f:write(k,"\n") end f:close()
end
local function clr_seen()
  if WS=="\\" then os.execute('del /q "'..cdir()..'\\*.seen" >nul 2>nul')
  else os.execute("rm -f "..sh(cdir()).."/*.seen 2>/dev/null") end
end

local function tok()
  local t=os.getenv("GITHUB_TOKEN")
  if t and #t>0 then return t end
  local f=io.open(home().."/.config/ghfind/token","r")
  if f then local s=f:read("*l") f:close() if s and #s>0 then return s end end
  local c=load_cfg()
  if c.token and #c.token>0 then return c.token end
  return nil
end

local function GET(u)
  local tk=tok()
  local cmd="curl -sS -L --max-time 25 -D -"
  if tk then cmd=cmd.." -H "..sh("Authorization: Bearer "..tk) end
  cmd=cmd.." -H "..sh("Accept: application/vnd.github+json")
  cmd=cmd.." -H "..sh("User-Agent: ghfind-lua")
  cmd=cmd.." "..sh(u)
  local f=io.popen(cmd,"r") if not f then return end end
  local r=f:read("*a") f:close()
  local hdr,bdy=r:match("^(.-)\r?\n\r?\n(.*)$")
  if not hdr then return nil,r end
  return hdr,bdy
end

local function HEAD(u)
  local tk=tok()
  local cmd="curl -sS -I -L --max-time 25"
  if tk then cmd=cmd.." -H "..sh("Authorization: Bearer "..tk) end
  cmd=cmd.." -H "..sh("Accept: application/vnd.github+json")
  cmd=cmd.." -H "..sh("User-Agent: ghfind-lua")
  cmd=cmd.." "..sh(u)
  local f=io.popen(cmd,"r") if not f then return end end
  local r=f:read("*a") f:close()
  return r
end

local function opn(u)
  if WS=="\\" then os.execute('start "" '..sh(u).." >nul 2>nul")
  else os.execute("(command -v open >/dev/null 2>&1 && open "..sh(u)..
    " ) || xdg-open "..sh(u).." >/dev/null 2>&1 &") end
end

local function ntf(t,b)
  if WS=="\\" then return end
  local o=os.getenv("OSTYPE") or ""
  if o:match("darwin") then
    os.execute("osascript -e "..sh("display notification "..sh(b)..
      " with title "..sh(t)).." 2>/dev/null &")
  else os.execute("notify-send "..sh(t).." "..sh(b).." 2>/dev/null &") end
end

local function slp(n)
  if WS=="\\" then os.execute("ping -n "..(n+1).." 127.0.0.1 >nul")
  else os.execute("sleep "..n) end
end

local function ask(prompt)
  io.write(prompt) io.flush()
  local l=io.read("*l") return l or ""
end

local function clr()
  if WS=="\\" then os.execute("cls") else os.execute("clear") end
end

local function hline(w)
  print(g(string.rep("─",w or 60),"2"))
end

local function banner()
  print("")
  print("  "..g("🐣 ghfind","1;36").."  "..g("repo searcher","2"))
  print("")
end

local function menu()
  banner()
  print("  "..g("1","1;33").."  Search")
  print("  "..g("2","1;33").."  Filters")
  print("  "..g("3","1;33").."  Watch")
  print("  "..g("4","1;33").."  Favorites")
  print("  "..g("5","1;33").."  History")
  print("  "..g("6","1;33").."  Token")
  print("  "..g("7","1;33").."  Settings")
  print("  "..g("8","1;33").."  Help")
  print("  "..g("9","1;33").."  Clear screen")
  print("  "..g("0","1;33").."  Exit")
  print("")
  return ask("  "..g("›","1;36").." ")
end

local FILT = { lang="", sort="", stars="", age="", limit=5 }

local function show_filters()
  print("")
  print("  "..g("active filters","1;36"))
  hline(40)
  print("  language  "..g(FILT.lang~="" and FILT.lang or "—","1;33"))
  print("  sort      "..g(FILT.sort~="" and FILT.sort or "—","1;33"))
  print("  min stars "..g(FILT.stars~="" and FILT.stars or "—","1;33"))
  print("  max age   "..g(FILT.age~="" and (FILT.age.."d") or "—","1;33"))
  print("  limit     "..g(FILT.limit,"1;33"))
  print("")
end

local function build_q(q)
  local s=q
  if FILT.lang~="" then s=s.." language:"..FILT.lang end
  if FILT.stars~="" then s=s.." stars:>="..FILT.stars end
  if FILT.age~="" then
    local d=os.date("*t")
    local t=os.time({year=d.year,month=d.month,day=d.day})
    t=t-tonumber(FILT.age)*86400
    s=s.." pushed:>"..os.date("%Y-%m-%d",t)
  end
  return s
end

local function run_search(q,opts)
  local url="https://api.github.com/search/repositories?q="..ue(build_q(q))..
            "&per_page="..math.max(1,math.min((opts and opts.per or FILT.limit)*3,100))
  if FILT.sort~="" then url=url.."&sort="..FILT.sort.."&order=desc" end
  local _,body=GET(url)
  if not body or body=="" then return nil,"no response" end
  local ok,D=pcall(J,body)
  if not ok or type(D)~="table" then return nil,"bad json" end
  if D.message and not D.items then return nil,D.message end
  return D
end

local function print_results(items,n)
  if #items==0 then print("  "..g("🫧 nothing","2")) return end
  for i,r in ipairs(items) do
    if i>n then break end
    local fn=r.full_name or "?"
    local ds=r.description or "—"
    local st=nb(r.stargazers_count) local fk=nb(r.forks_count)
    local lg=r.language or "—"
    local dt=(r.updated_at or ""):sub(1,10)
    print("  "..g(i..".","1;35").." "..g(fn,"1;36")..
          "   "..g("⭐ "..st,"33").."  "..g("🍴 "..fk,"33"))
    local buf=""
    for w in ds:gmatch"%S+" do
      if #buf+#w+1>66 then print("     "..g(buf,"2")) buf=w
      else buf=(buf=="" and w) or (buf.." "..w) end
    end
    if buf~="" then print("     "..g(buf,"2")) end
    print("     "..g(lg.."  "..dt,"90"))
    print("     "..g(r.html_url or "","4;34"))
    print("")
  end
end

local function do_search()
  clr() banner()
  local q=ask("  "..g("query","1;36").." › ")
  if q=="" then return end
  print("")
  print("  "..g("🔎 searching…","2"))
  local D,er=run_search(q)
  if not D then
    print("  "..g("😿 "..tostring(er),"1;31")) slp(2) return
  end
  clr() banner()
  print("  "..g("query","2").."  "..g(q,"1;33"))
  show_filters()
  local items=D.items or {}
  print_results(items,FILT.limit)
  print("  "..g(nb(D.total_count or #items).." total","2"))
  print("")
  local a=ask("  "..g("[o]pen first  [c]lone  [s]ave  [enter]back › ","1;36"))
  if a=="o" and items[1] then opn(items[1].html_url)
  elseif a=="c" and items[1] then
    local d=ask("  clone to (blank = cwd) › ")
    local cmd="git clone "..sh(items[1].clone_url or items[1].html_url..".git")
    if d~="" then cmd=cmd.." "..sh(d) end
    print("  "..g(cmd,"2")) os.execute(cmd)
    ask("  [enter]")
  elseif a=="s" then
    local f=ask("  save to › ")
    if f~="" then
      local fp=io.open(f,"a")
      if fp then
        for _,r in ipairs(items) do
          fp:write(r.full_name or "?","\t",r.html_url or "","\t",
                   tostring(r.stargazers_count or 0),"\n")
        end
        fp:close() print("  "..g("saved","1;32")) slp(1)
      end
    end
  end
end

local function do_filters()
  while true do
    clr() banner()
    show_filters()
    print("  "..g("1","1;33").."  language  (lua/python/rust/…)")
    print("  "..g("2","1;33").."  sort      (stars/forks/updated)")
    print("  "..g("3","1;33").."  min stars")
    print("  "..g("4","1;33").."  max age (days)")
    print("  "..g("5","1;33").."  limit")
    print("  "..g("6","1;33").."  reset all")
    print("  "..g("0","1;33").."  back")
    print("")
    local c=ask("  "..g("›","1;36").." ")
    if c=="0" then return end
    if c=="1" then FILT.lang=ask("  language › ")
    elseif c=="2" then
      local s=ask("  sort (stars/forks/updated) › ")
      if s=="stars" or s=="forks" or s=="updated" then FILT.sort=s
      else FILT.sort="" end
    elseif c=="3" then FILT.stars=ask("  min stars › ")
    elseif c=="4" then FILT.age=ask("  max age (days) › ")
    elseif c=="5" then FILT.limit=tonumber(ask("  limit › ")) or 5
    elseif c=="6" then FILT={lang="",sort="",stars="",age="",limit=5} end
  end
end

local function do_watch()
  clr() banner()
  local q=ask("  query › ")
  if q=="" then return end
  local secs=tonumber(ask("  every how many seconds? › ")) or 60
  local maxp=tonumber(ask("  max passes (blank = forever) › "))
  local notify=ask("  desktop notifications? [y/N] › "):lower()=="y"
  local seen,sp=ld_seen(q)
  local n=0
  print("")
  print("  "..g("👀 watching — ctrl-c to stop","1;36"))
  while true do
    n=n+1
    local D,er=run_search(q,{per=FILT.limit})
    if not D then
      print("  "..g("❌ "..tostring(er),"1;31"))
    else
      local fresh={}
      for _,r in ipairs(D.items or {}) do
        if not seen[r.full_name] then
          fresh[#fresh+1]=r seen[r.full_name]=true
        end
      end
      if #fresh>0 then
        print("")
        print("  "..g("🆕 "..#fresh.." new","1;32")..
              "  ·  pass "..n.."  ·  "..os.date("%H:%M:%S"))
        print_results(fresh,FILT.limit)
        sv_seen(seen,sp)
        if notify then ntf("ghfind: "..q,#fresh.." new") end
      else
        io.write("  ·  pass "..n.."  no change\n")
      end
    end
    if maxp and n>=maxp then break end
    slp(secs)
  end
  ask("  [enter]")
end

local function do_favs()
  local fp=home()..WS..".config"..WS.."ghfind"..WS.."favorites.txt"
  while true do
    clr() banner()
    local list={}
    local f=io.open(fp,"r")
    if f then for l in f:lines() do
      if #l>0 then
        local name,url=l:match("^(.-)\t(.*)$")
        if name then list[#list+1]={name=name,url=url or ""} end
      end
    end f:close() end
    print("  "..g("★ favorites","1;36").."  "..g("("..#list..")","2"))
    hline(40)
    if #list==0 then print("  "..g("empty","2"))
    else
      for i,fv in ipairs(list) do
        print("  "..g(i..".","1;35").." "..g(fv.name,"1;36"))
      end
    end
    print("")
    print("  "..g("a","1;33").."  add      "..g("d","1;33").."  delete")
    print("  "..g("o","1;33").."  open #   "..g("e","1;33").."  export")
    print("  "..g("0","1;33").."  back")
    print("")
    local c=ask("  "..g("›","1;36").." ")
    if c=="0" then return end
    if c=="a" then
      local n=ask("  name › ")
      local u=ask("  url › ")
      if n~="" and u~="" then
        local d=cfg_path():match("^(.*)"..WS.."[^"..WS.."]+$")
        if d then mkp(d) end
        local w=io.open(fp,"a")
        if w then w:write(n,"\t",u,"\n") w:close() end
      end
    elseif c=="d" then
      local i=tonumber(ask("  number › "))
      if i and list[i] then
        list[i]=nil
        local w=io.open(fp,"w")
        if w then for _,fv in ipairs(list) do
          w:write(fv.name,"\t",fv.url,"\n") end w:close() end
      end
    elseif c=="o" then
      local i=tonumber(ask("  number › "))
      if i and list[i] then opn(list[i].url) end
    elseif c=="e" then
      for _,fv in ipairs(list) do print(fv.name.."\t"..fv.url) end
      ask("  [enter]")
    end
  end
end

local function do_hist()
  local hp=home()..WS..".config"..WS.."ghfind"..WS.."history.txt"
  while true do
    clr() banner()
    local list={}
    local f=io.open(hp,"r")
    if f then for l in f:lines() do
      if #l>0 and #list<30 then list[#list+1]=l end
    end f:close() end
    print("  "..g("▤ history","1;36").."  "..g("("..#list..")","2"))
    hline(40)
    if #list==0 then print("  "..g("empty","2"))
    else
      for i,h in ipairs(list) do
        print("  "..g(i..".","1;35").." "..g(h,"1;36"))
      end
    end
    print("")
    print("  "..g("r","1;33").."  rerun #   "..g("c","1;33").."  clear")
    print("  "..g("0","1;33").."  back")
    print("")
    local c=ask("  "..g("›","1;36").." ")
    if c=="0" then return end
    if c=="c" then os.remove(hp)
    elseif c=="r" then
      local i=tonumber(ask("  number › "))
      if i and list[i] then
        print("") print("  "..g("🔎 "..list[i],"1;36"))
        local D=run_search(list[i])
        if D then print_results(D.items or {},FILT.limit) end
        ask("  [enter]")
      end
    end
  end
end

local function hist_push(q)
  local hp=home()..WS..".config"..WS.."ghfind"..WS.."history.txt"
  local d=hp:match("^(.*)"..WS.."[^"..WS.."]+$")
  if d then mkp(d) end
  local f=io.open(hp,"a")
  if f then f:write(q,"\n") f:close() end
end

local function do_token()
  while true do
    clr() banner()
    local t=tok()
    print("  "..g("🔐 token","1;36"))
    hline(40)
    if t then
      print("  status  "..g("set","1;32").."  "..g(t:sub(1,8).."…","2"))
    else
      print("  status  "..g("not set","1;33"))
    end
    print("")
    print("  "..g("1","1;33").."  paste a token")
    print("  "..g("2","1;33").."  check current token")
    print("  "..g("3","1;33").."  remove saved token")
    print("  "..g("4","1;33").."  what scopes should i use?")
    print("  "..g("0","1;33").."  back")
    print("")
    local c=ask("  "..g("›","1;36").." ")
    if c=="0" then return end
    if c=="1" then
      local v=ask("  token › ")
      if v~="" then
        local c2=load_cfg() c2.token=v save_cfg(c2)
        print("  "..g("saved to config.lua","1;32")) slp(1)
      end
    elseif c=="2" then
      local h=HEAD("https://api.github.com/user")
      if not h then slp(1) else
        local code
        for l in h:gmatch"[^\r\n]+" do
          code=l:match"^HTTP/%d%.%d%s+(%d+)" or code
        end
        if code=="401" then
          print("  "..g("🚨 invalid token","1;31"))
        else
          local ol=h:match"\n[Oo]auth%-[Ss]copes:%s*([^\r\n]+)"
                  or h:match"^[Oo]auth%-[Ss]copes:%s*([^\r\n]+)"
          if not ol or ol=="" then
            print("  "..g("scopes:","1;36").." none")
            print("  "..g("✅ perfect","1;32"))
          else
            local any=false
            for s in ol:gmatch"[^,%s]+" do
              any=true
              local danger=s=="repo" or s=="user" or s=="security_events"
                or s=="delete_repo" or s=="admin:org" or s=="workflow"
              print("  "..(danger and g("🚨","1;31") or g("✅","1;32")).."  "..s)
            end
            if not any then print("  "..g("✅ none","1;32")) end
          end
        end
        ask("  [enter]")
      end
    elseif c=="3" then
      local c2=load_cfg() c2.token=nil save_cfg(c2)
      print("  "..g("removed","1;32")) slp(1)
    elseif c=="4" then
      clr() banner()
      print("  "..g("recommended:","1;36"))
      print("  "..g("✅ none","1;32").."  — classic token, zero boxes")
      print("  "..g("🟢 public_repo","1;36").."  — if you insist")
      print("")
      print("  "..g("avoid:","1;31"))
      for _,s in ipairs{"repo","user","security_events","delete_repo",
                        "admin:org","workflow"} do
        print("  "..g("🚨 "..s,"1;31"))
      end
      print("")
      print("  "..g("https://github.com/settings/tokens","2"))
      ask("  [enter]")
    end
  end
end

local function do_settings()
  while true do
    clr() banner()
    local c=load_cfg()
    print("  "..g("⚙ settings","1;36"))
    hline(40)
    print("  default limit   "..g(c.default_limit or FILT.limit,"1;33"))
    print("  notifications   "..g(c.notify and "on" or "off","1;33"))
    print("  auto-open top   "..g(c.auto_open and "on" or "off","1;33"))
    print("  default lang    "..g(c.default_lang or "—","1;33"))
    print("")
    print("  "..g("1","1;33").."  default limit")
    print("  "..g("2","1;33").."  toggle notifications")
    print("  "..g("3","1;33").."  toggle auto-open top")
    print("  "..g("4","1;33").."  default language")
    print("  "..g("5","1;33").."  wipe seen cache")
    print("  "..g("6","1;33").."  reset all settings")
    print("  "..g("0","1;33").."  back")
    print("")
    local k=ask("  "..g("›","1;36").." ")
    if k=="0" then return end
    if k=="1" then
      local v=tonumber(ask("  limit › "))
      if v then c.default_limit=v save_cfg(c) FILT.limit=v end
    elseif k=="2" then
      c.notify=not c.notify save_cfg(c)
    elseif k=="3" then
      c.auto_open=not c.autif D.message and not D.items then return nil, D.message end
  return D
end

local function filt(items, o, seen)
  local r = {}
  for _, it in ipairs(items) do
    local keep = true
    if o.ms and (tonumber(it.stargazers_count) or 0) < o.ms then keep=false end
    if seen and seen[it.full_name] then keep=false end
    if keep then r[#r+1] = it end
  end
  return r
end

local function show(items, n, o)
  for i, r in ipairs(items) do
    if i > n then break end
    local fn=r.full_name or "?"
    local ds=r.description or "?"
    local st=nb(r.stargazers_count) local fk=nb(r.forks_count)
    local lg=r.language or "—"
    local dt=(r.updated_at or ""):sub(1,10)
    local lnk=r.html_url or ("https://github.com/"..fn)
    print("  "..g(i..".","1;35").." "..g(fn,"1;36").."   "..
          g("⭐ "..st,"33").."  "..g("🍴 "..fk,"33"))
    local buf=""
    for w in ds:gmatch"%S+" do
      if #buf+#w+1>66 then print("     "..g(buf,"2")) buf=w
      else buf=(buf=="" and w) or (buf.." "..w) end
    end
    if buf~="" then print("     "..g(buf,"2")) end
    print("     "..g(lg.."  "..dt,"90"))
    print("     "..g(lnk,"4;34").."\n")
  end
end

local function js_esc(s)
  if s==nil then return "null" end
  s = tostring(s):gsub('\\','\\\\'):gsub('"','\\"')
                :gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')
  return '"'..s..'"'
end
local function dump_json(items)
  local b={"["}
  for i,r in ipairs(items) do
    if i>1 then b[#b+1]="," end
    b[#b+1]='{"full_name":'..js_esc(r.full_name)..
            ',"description":'..js_esc(r.description)..
            ',"stars":'..tostring(r.stargazers_count or 0)..
            ',"forks":'..tostring(r.forks_count or 0)..
            ',"language":'..js_esc(r.language)..
            ',"updated_at":'..js_esc(r.updated_at)..
            ',"url":'..js_esc(r.html_url)..
            ',"clone_url":'..js_esc(r.clone_url)..'}'
  end
  b[#b+1]="]"
  print(table.concat(b))
end

local function append_file(p, items)
  local f = io.open(p, "a")
  if not f then return end
  for _, r in ipairs(items) do
    f:write(r.full_name or "?", "\t", r.html_url or "", "\t",
            tostring(r.stargazers_count or 0), "\n")
  end
  f:close()
end

local function pick_rand(items)
  if #items == 0 then return nil end
  math.randomseed(os.time() + math.floor(os.clock()*1000))
  return items[math.random(1, #items)]
end

local H = [[
ghfind 🐣  — automation edition

  lua ghfind.lua "words" [opts]

search:
  -l/--lang X       language
  -s/--sort X       stars | forks | updated
  -n/--limit N      how many (5)
  --min-stars N     only repos with N+ stars
  --pushed DATE     pushed after YYYY-MM-DD

action:
  -o/--open         open top result in browser
  -c/--clone [DIR]  git clone top result
  --random          pick a random result

automation:
  -w/--watch N      repeat every N seconds, show only new
  -W N              max watch passes
  --seen            skip already-seen (cached in ~/.cache/ghfind)
  --clear-seen      wipe seen cache
  --notify          desktop notification on new (watch mode)
  --save FILE       append results to FILE
  --json            json output (pipe-friendly)

misc:
  -t/--check-token  inspect token scopes
  -r/--recommend    safe scopes
  -h/--help         this

examples:
  lua ghfind.lua "neovim colorscheme" -s stars -o
  lua ghfind.lua "http server" -l lua -c ~/src
  lua ghfind.lua "markdown parser" -w 120 --seen --notify
  lua ghfind.lua "tui fm" --json | jq
]]

local function argv(a)
  local o={w={},n=5} local i=1
  local function nv() i=i+1 return a[i] end
  while i<=#a do
    local v=a[i]
    local k,val=v:match"^(%-%-[%w%-]+)=(.*)$"
    if k then a[i]=k table.insert(a,i+1,val) v=k end
    if     v=="-h" or v=="--help"       then io.write(H) os.exit(0)
    elseif v=="-t" or v=="--check-token" then o.t=1
    elseif v=="-r" or v=="--recommend"   then o.r=1
    elseif v=="-l" or v=="--lang"        then o.l=nv()
    elseif v=="-s" or v=="--sort"        then o.s=nv()
    elseif v=="-n" or v=="--limit"       then o.n=tonumber(nv()) or 5
    elseif v=="-w" or v=="--watch"       then o.ws=tonumber(nv()) or 60
    elseif v=="-W"                       then o.wm=tonumber(nv())
    elseif v=="--min-stars"              then o.ms=tonumber(nv())
    elseif v=="--pushed"                 then o.ph=nv()
    elseif v=="-o" or v=="--open"        then o.op=1
    elseif v=="-c" or v=="--clone" then
      local nx=a[i+1]
      if nx and not nx:match("^%-") then o.cl=nx i=i+1 else o.cl="" end
    elseif v=="--random"                 then o.rd=1
    elseif v=="--seen"                   then o.sn=1
    elseif v=="--clear-seen"             then o.clr=1
    elseif v=="--notify"                 then o.nt=1
    elseif v=="--save"                   then o.sv=nv()
    elseif v=="--json"                   then o.js=1
    else o.w[#o.w+1]=v end
    i=i+1
  end
  return o
end

local A = argv(arg)
if A.clr then clr_seen() print("  🧹  cache cleared") os.exit(0) end
if A.r then rec() os.exit(0) end
if A.t then chk() os.exit(0) end
if #A.w==0 then io.write(H) os.exit(1) end

local q = table.concat(A.w," ")
if A.l and #A.l>0 then q=q.." language:"..A.l end
if A.ph then q=q.." pushed:>"..A.ph end

if A.ws then
  local seen, spath = ld_seen(q)
  local n = 0
  if not A.js then
    io.write("\n  👀  "..g('"'..q..'"',"1;33")..
             "  every "..A.ws.."s")
    if A.wm then io.write("  (max "..A.wm..")") end
    io.write("\n\n")
  end
  while true do
    n = n + 1
    local D, er = one(q, A)
    if not D then
      if not A.js then io.write("  ❌  "..tostring(er).."\n") end
    else
      local fresh = {}
      for _, r in ipairs(D.items or {}) do
        if not seen[r.full_name] then
          fresh[#fresh+1] = r
          seen[r.full_name] = true
        end
      end
      if #fresh > 0 then
        if A.js then
          dump_json(fresh)
        else
          print("  🆕  "..g(tostring(#fresh).." new","1;32")..
                "  ·  pass "..n.."  ·  "..os.date("%H:%M:%S"))
          print("")
          show(fresh, A.n, A)
        end
        sv_seen(seen, spath)
        if A.sv then append_file(A.sv, fresh) end
        if A.nt then ntf("ghfind: "..q, #fresh.." new") end
        if A.op and fresh[1] then opn(fresh[1].html_url) end
        if A.cl and fresh[1] then clone_it(fresh[1].clone_url, A.cl) end
      else
        if not A.js then
          io.write("  ·  pass "..n.."  no change\n")
        end
      end
    end
    if A.wm and n >= A.wm then break end
    slp(A.ws)
  end
  os.exit(0)
end

local D, er = one(q, A)
if not D then
  if A.js then print("[]")
  else io.stderr:write("  😿  "..tostring(er).."\n\n") end
  os.exit(1)
end

local items = D.items or {}
if A.sn then
  local seen, spath = ld_seen(q)
  items = filt(items, A, seen)
  for _, r in ipairs(items) do seen[r.full_name] = true end
  sv_seen(seen, spath)
else
  items = filt(items, A, nil)
end

if #items == 0 then
  if A.js then print("[]") else print("  🫧  nothing\n") end
  os.exit(0)
end

if A.js then dump_json(items) os.exit(0) end

if A.rd then
  local r = pick_rand(items)
  items = r and {r} or {}
  if #items == 0 then print("  🫧  nothing\n") os.exit(0) end
end

if A.op and items[1] then opn(items[1].html_url) end
if A.cl and items[1] then clone_it(items[1].clone_url, A.cl) end
if A.sv then append_file(A.sv, items) end

io.write("\n  🔎  "..g(q,"1;33").."\n\n")
show(items, A.n, A)
print("  "..g(nb(D.total_count or #items).." · "..math.min(#items, A.n),"2").."\n")
