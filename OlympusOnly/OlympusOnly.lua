--[[
  OlympusOnly
  Classic / WoW Forever addon.

  Allow a player only if their guild name starts with OLYMPUS.
  Blacklist players who have a different guild, or no guild.
  Unknown players (guild not yet readable) stay visible until classified.
]]

local ADDON_NAME = ...
local PREFIX = "OLYMPUS"

local db
local frame = CreateFrame("Frame", "OlympusOnlyFrame")

local DEFAULTS = {
  enabled = true,
  prefix = PREFIX,
  hideChat = true,
  blockPartyInvites = true,
  blockGuildInvites = true,
  notify = true,
  scanUnits = true,
  blacklist = {}, -- [key] = { name=, guild=, added=, reason= }
}

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function Print(msg)
  local prefix = "|cffd4af37OlympusOnly|r: "
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg))
  end
end

local function Notify(msg)
  if db and db.notify then
    Print(msg)
  end
end

local function CopyDefaults(src, dst)
  if type(dst) ~= "table" then
    dst = {}
  end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

local function StripRealm(name)
  if not name or name == "" then
    return nil
  end
  name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  name = name:match("^([^%-]+)") or name
  name = name:match("^%s*(.-)%s*$") or name
  if name == "" then
    return nil
  end
  return name
end

local function NameKey(name)
  name = StripRealm(name)
  if not name then
    return nil
  end
  return name:lower()
end

local function StartsWithOlympus(guild)
  if not guild or guild == "" then
    return false
  end
  local prefix = (db and db.prefix) or PREFIX
  return guild:upper():sub(1, #prefix) == prefix:upper()
end

local function IsSelfName(name)
  local me = UnitName("player")
  if not me or not name then
    return false
  end
  return NameKey(me) == NameKey(name)
end

------------------------------------------------------------------------
-- Allow only OLYMPUS guilds. Block other guilds and unguilded players.
------------------------------------------------------------------------

local function IsBlacklisted(name)
  local key = NameKey(name)
  return key and db and db.blacklist[key] ~= nil
end

local function AddBlacklist(name, guild, reason)
  local key = NameKey(name)
  if not key or not db then
    return false
  end
  local display = StripRealm(name)
  if db.blacklist[key] then
    db.blacklist[key].guild = guild or db.blacklist[key].guild
    db.blacklist[key].reason = reason or db.blacklist[key].reason
    return false
  end
  db.blacklist[key] = {
    name = display,
    guild = guild or "",
    added = time(),
    reason = reason or "guild is not OLYMPUS",
  }
  local tag = (guild and guild ~= "") and guild or "no guild"
  Notify(string.format("Blacklisted %s [%s].", display, tag))
  return true
end

local function RemoveBlacklist(name)
  local key = NameKey(name)
  if not key or not db or not db.blacklist[key] then
    return false
  end
  local display = db.blacklist[key].name or StripRealm(name)
  db.blacklist[key] = nil
  Print("Removed " .. display .. " from the blacklist.")
  return true
end

-- nil guild  = unknown, leave alone
-- "" guild   = confirmed unguilded, blacklist
-- OLYMPUS*   = allow (and drop them from the blacklist if they were on it)
-- other      = blacklist
local function Classify(name, guild)
  if not db or not db.enabled then
    return
  end
  name = StripRealm(name)
  if not name or IsSelfName(name) then
    return
  end
  if guild == nil then
    return
  end
  if StartsWithOlympus(guild) then
    local key = NameKey(name)
    if key and db.blacklist[key] then
      local old = db.blacklist[key]
      db.blacklist[key] = nil
      Notify(string.format("Unblacklisted %s (now %s).", old.name or name, guild))
    end
    return
  end
  if guild == "" then
    AddBlacklist(name, "", "no guild")
    return
  end
  AddBlacklist(name, guild, "guild is not OLYMPUS")
end

local function ScanUnit(unit)
  if not db or not db.enabled or not db.scanUnits then
    return
  end
  if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
    return
  end
  local name = UnitName(unit)
  if not name then
    return
  end
  local guild = GetGuildInfo(unit)
  -- GetGuildInfo returns nil both for "unknown" and "unguilded".
  -- If the unit is visible, treat a missing guild as unguilded.
  if guild == nil and UnitIsVisible(unit) then
    guild = ""
  end
  Classify(name, guild)
end

local function ScanGroup()
  if UnitInRaid("player") then
    for i = 1, 40 do
      ScanUnit("raid" .. i)
    end
  elseif UnitInParty("player") then
    for i = 1, 4 do
      ScanUnit("party" .. i)
    end
  end
end

local function GetWhoEntry(index)
  if C_FriendList and C_FriendList.GetWhoInfo then
    local a, b = C_FriendList.GetWhoInfo(index)
    if type(a) == "table" then
      local name = a.fullName or a.Name or a.name
      local guild = a.fullGuildName or a.Guild or a.guildName or a.guild or a.GuildName
      return name, guild or ""
    elseif type(a) == "string" then
      return a, b or ""
    end
  end
  if GetWhoInfo then
    local name, guild = GetWhoInfo(index)
    return name, guild or ""
  end
end

local function GetWhoCount()
  if C_FriendList and C_FriendList.GetNumWhoResults then
    local num, total = C_FriendList.GetNumWhoResults()
    return num or total or 0
  end
  if GetNumWhoResults then
    local num, total = GetNumWhoResults()
    return num or total or 0
  end
  return 0
end

local function ScanWhoResults()
  if not db or not db.enabled then
    return 0
  end
  local n = GetWhoCount()
  local seen = 0
  for i = 1, n do
    local name, guild = GetWhoEntry(i)
    if name then
      seen = seen + 1
      Classify(name, guild or "")
    end
  end
  return seen
end

local function RequestWhoToUI()
  if C_FriendList and C_FriendList.SetWhoToUi then
    C_FriendList.SetWhoToUi(true)
  elseif SetWhoToUI then
    SetWhoToUI(1)
  end
end

local function HookWhoSend()
  if C_FriendList and C_FriendList.SendWho and not C_FriendList._OlympusOnlyHooked then
    local orig = C_FriendList.SendWho
    C_FriendList.SendWho = function(...)
      RequestWhoToUI()
      return orig(...)
    end
    C_FriendList._OlympusOnlyHooked = true
  end
  if SendWho and not _G.OlympusOnly_SendWhoHooked then
    hooksecurefunc("SendWho", function()
      RequestWhoToUI()
    end)
    _G.OlympusOnly_SendWhoHooked = true
  end
end

-- Yellow /who lines when results print to chat instead of the Who window.
-- Guilded:   [Name]: Level 60 Race Class <Guild> - Zone
-- Unguilded: [Name]: Level 60 Race Class - Zone
local function ClassifyWhoChatLine(msg)
  if not msg or msg == "" then
    return false
  end
  -- Ignore "n players total" / "Players found" summary lines.
  if msg:find("Found") and not msg:find("Level") then
    return false
  end
  if not msg:find("Level") then
    return false
  end

  local name = msg:match("|Hplayer:([^|:]+)")
  if not name then
    name = msg:match("^([^:]+):%s+Level%s+%d+")
  end
  if not name then
    return false
  end

  local guild = msg:match("<([^>]+)>")
  if guild and guild ~= "" then
    Classify(name, guild)
  else
    Classify(name, "")
  end
  return true
end

------------------------------------------------------------------------
-- Chat filter
------------------------------------------------------------------------

local CHAT_EVENTS = {
  "CHAT_MSG_SAY",
  "CHAT_MSG_YELL",
  "CHAT_MSG_EMOTE",
  "CHAT_MSG_TEXT_EMOTE",
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_CHANNEL",
  "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER",
  "CHAT_MSG_RAID_WARNING",
  "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "CHAT_MSG_BATTLEGROUND",
  "CHAT_MSG_BATTLEGROUND_LEADER",
}

local function ChatFilter(_, event, msg, author, ...)
  if not db or not db.enabled or not db.hideChat then
    return false
  end
  if not author or author == "" or IsSelfName(author) then
    return false
  end
  if IsBlacklisted(author) then
    return true
  end
  return false
end

local function RegisterChatFilters()
  if not ChatFrame_AddMessageEventFilter then
    return
  end
  for _, event in ipairs(CHAT_EVENTS) do
    ChatFrame_AddMessageEventFilter(event, ChatFilter)
  end
end

------------------------------------------------------------------------
-- Invites
------------------------------------------------------------------------

local function HidePartyPopup()
  if StaticPopup_Hide then
    StaticPopup_Hide("PARTY_INVITE")
    StaticPopup_Hide("PARTY_INVITE_XREALM")
  end
  if StaticPopupSpecial_Hide and LFGInvitePopup then
    StaticPopupSpecial_Hide(LFGInvitePopup)
  end
end

local function HideGuildPopup()
  if StaticPopup_Hide then
    StaticPopup_Hide("GUILD_INVITE")
  end
end

local function DeclinePartyInvite(sender, why)
  if DeclineGroup then
    DeclineGroup()
  end
  HidePartyPopup()
  Notify(string.format("Declined party invite from %s (%s).", sender or "?", why or "non-OLYMPUS guild"))
end

local function DeclineGuildInvite(inviter, guild, why)
  if DeclineGuild then
    DeclineGuild()
  end
  HideGuildPopup()
  Notify(string.format("Declined guild invite to %s from %s (%s).", guild or "?", inviter or "?", why or "not OLYMPUS"))
end

local function HandlePartyInvite(sender)
  if not db or not db.enabled or not db.blockPartyInvites then
    return
  end
  sender = StripRealm(sender)
  if not sender then
    return
  end
  if IsBlacklisted(sender) then
    DeclinePartyInvite(sender, "blacklisted")
    return
  end
  local guild = GetGuildInfo(sender)
  if guild and guild ~= "" and not StartsWithOlympus(guild) then
    Classify(sender, guild)
    DeclinePartyInvite(sender, "guild: " .. guild)
  end
end

local function HandleGuildInvite(inviter, guildName)
  if not db or not db.enabled or not db.blockGuildInvites then
    return
  end
  if not guildName or guildName == "" or StartsWithOlympus(guildName) then
    return
  end
  if inviter then
    Classify(inviter, guildName)
  end
  DeclineGuildInvite(inviter, guildName, "guild is not OLYMPUS")
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

frame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name ~= ADDON_NAME then
      return
    end
    OlympusOnlyDB = CopyDefaults(DEFAULTS, OlympusOnlyDB)
    db = OlympusOnlyDB
    db.whitelist = nil
    db.strictPartyInvites = nil
    RegisterChatFilters()
    HookWhoSend()
    Print("Loaded. Allowed only with an OLYMPUS guild. No guild or any other guild is blacklisted. Type |cffffffff/oo|r for help.")
    return
  end

  if not db then
    return
  end

  if event == "PLAYER_LOGIN" then
    ScanGroup()
    return
  end

  if not db.enabled then
    return
  end

  if event == "PLAYER_TARGET_CHANGED" then
    ScanUnit("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    ScanUnit("mouseover")
  elseif event == "PLAYER_FOCUS_CHANGED" then
    ScanUnit("focus")
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    ScanUnit(...)
  elseif event == "GROUP_ROSTER_UPDATE" then
    ScanGroup()
  elseif event == "WHO_LIST_UPDATE" then
    ScanWhoResults()
  elseif event == "CHAT_MSG_SYSTEM" then
    local msg = ...
    if ClassifyWhoChatLine(msg) then
      ScanWhoResults()
    end
  elseif event == "PARTY_INVITE_REQUEST" then
    local sender = ...
    HandlePartyInvite(sender)
    if sender and IsBlacklisted(sender) then
      HidePartyPopup()
    end
  elseif event == "GUILD_INVITE_REQUEST" then
    local inviter, guildName = ...
    HandleGuildInvite(inviter, guildName)
  end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("WHO_LIST_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("GUILD_INVITE_REQUEST")
pcall(function()
  frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
end)
pcall(function()
  frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

local function Count(tbl)
  local n = 0
  for _ in pairs(tbl or {}) do
    n = n + 1
  end
  return n
end

local function SortedKeys(tbl)
  local keys = {}
  for k in pairs(tbl or {}) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  return keys
end

local function PrintHelp()
  Print("Allowed only with an OLYMPUS guild. No guild or other guilds are blacklisted.")
  Print("  |cffffffff/oo|r                status")
  Print("  |cffffffff/oo on|off|r         enable / disable")
  Print("  |cffffffff/oo list|r           show blacklist")
  Print("  |cffffffff/oo add Name|r       force-blacklist a name")
  Print("  |cffffffff/oo remove Name|r    remove a name from the blacklist")
  Print("  |cffffffff/oo check Name|r     look up a name")
  Print("  |cffffffff/oo scan|r           scan target / mouseover / group / who now")
  Print("  |cffffffff/oo who|r            scan the current /who results")
  Print("  |cffffffff/oo clearblack|r     wipe the blacklist")
  Print("  |cffffffff/oo notify on|off|r  chat notifications")
  Print("  |cffffffff/oo prefix TEXT|r    federation prefix (default OLYMPUS)")
end

local function PrintStatus()
  Print(string.format(
    "%s  prefix=%s  blacklist=%d  chat=%s  partyInvites=%s  guildInvites=%s",
    db.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r",
    db.prefix or PREFIX,
    Count(db.blacklist),
    db.hideChat and "hide" or "show",
    db.blockPartyInvites and "block" or "allow",
    db.blockGuildInvites and "block" or "allow"
  ))
end

SLASH_OLYMPUSONLY1 = "/oo"
SLASH_OLYMPUSONLY2 = "/olympusonly"
SlashCmdList.OLYMPUSONLY = function(msg)
  if not db then
    Print("Not loaded yet.")
    return
  end
  msg = msg and msg:match("^%s*(.-)%s*$") or ""
  local cmd, rest = msg:match("^(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower() or ""

  if cmd == "" or cmd == "status" then
    PrintStatus()
  elseif cmd == "help" then
    PrintHelp()
  elseif cmd == "on" or cmd == "enable" then
    db.enabled = true
    Print("Enabled.")
  elseif cmd == "off" or cmd == "disable" then
    db.enabled = false
    Print("Disabled.")
  elseif cmd == "list" or cmd == "black" or cmd == "blacklist" then
    local keys = SortedKeys(db.blacklist)
    Print("Blacklist (" .. #keys .. "):")
    if #keys == 0 then
      Print("  (empty)")
    else
      for _, key in ipairs(keys) do
        local e = db.blacklist[key]
        Print(string.format("  %s  |cffaaaaaa[%s]|r", e.name or key, e.guild or "?"))
      end
    end
  elseif cmd == "add" or cmd == "block" then
    if rest == "" then
      Print("Usage: /oo add Name")
      return
    end
    AddBlacklist(rest, "", "manual")
  elseif cmd == "remove" or cmd == "del" or cmd == "unblacklist" then
    if rest == "" then
      Print("Usage: /oo remove Name")
      return
    end
    if not RemoveBlacklist(rest) then
      Print(StripRealm(rest) .. " is not on the blacklist.")
    end
  elseif cmd == "check" then
    if rest == "" then
      Print("Usage: /oo check Name")
      return
    end
    local key = NameKey(rest)
    local b = db.blacklist[key]
    if b then
      Print(string.format("%s is BLACKLISTED (guild: %s).", b.name, b.guild or "?"))
    else
      Print(StripRealm(rest) .. " is allowed.")
    end
  elseif cmd == "scan" then
    ScanUnit("target")
    ScanUnit("mouseover")
    ScanUnit("focus")
    ScanGroup()
    local who = ScanWhoResults()
    Print("Scan complete (" .. who .. " /who results).")
    PrintStatus()
  elseif cmd == "who" then
    local who = ScanWhoResults()
    Print("Scanned " .. who .. " /who result(s).")
    PrintStatus()
  elseif cmd == "clearblack" or cmd == "clear" then
    db.blacklist = {}
    Print("Blacklist cleared.")
  elseif cmd == "notify" then
    local v = rest:lower()
    if v == "on" then
      db.notify = true
    elseif v == "off" then
      db.notify = false
    else
      db.notify = not db.notify
    end
    Print("Notifications " .. (db.notify and "ON" or "OFF") .. ".")
  elseif cmd == "prefix" then
    if rest == "" then
      Print("Current prefix: " .. (db.prefix or PREFIX))
      return
    end
    db.prefix = rest:upper()
    Print("Federation prefix set to " .. db.prefix .. ".")
  else
    PrintHelp()
  end
end
