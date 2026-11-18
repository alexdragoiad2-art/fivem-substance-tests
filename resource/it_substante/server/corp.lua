-- it_substante / server/corp.lua - "corpul" fiecarui personaj: alcoolemie (‰) + THC + metamfetamina.
-- Autoritatea e serverul: testele politiei citesc de aici. Pastrat in KVP (si dupa relogare / restart).
-- Consumul: serverul primeste folosirea itemului, clientul joaca animatia, iar efectul se aplica abia
-- cand clientul confirma (itemul se scoate atunci, verificat) - cu jeton, ca sa nu se poata trisa.

local bodies = {}      -- [identifier] = corp
local pendingUse = {}  -- [src] = { item, at }

local A, D = Sub.Alcohol, Sub.Drugs

local function now() return os.time() end

local function newBody()
  return { bac = 0.0, pending = 0.0, t = now(), thc = {}, meth = {} }
end

local function kvpKey(identifier) return 'sub:' .. identifier end

local function load(identifier)
  if bodies[identifier] then return bodies[identifier] end
  local raw = GetResourceKvpString(kvpKey(identifier))
  local b = raw and json.decode(raw) or nil
  if type(b) ~= 'table' then b = newBody() end
  b.thc, b.meth = b.thc or {}, b.meth or {}
  b.bac, b.pending, b.t = tonumber(b.bac) or 0.0, tonumber(b.pending) or 0.0, tonumber(b.t) or now()
  bodies[identifier] = b
  return b
end

-- avanseaza alcoolul pana acum: absorbtie din stomac + eliminare, in pasi de cel mult 1 minut
local function advance(b)
  local t = now()
  local mins = (t - b.t) / 60.0
  if mins > 0 then
    if mins > 600 then mins = 600 end
    while mins > 0 do
      local step = mins > 1 and 1 or mins
      local a = math.min(b.pending, A.absorbPerMin * step)
      b.pending = b.pending - a
      b.bac = math.max(0.0, b.bac + a - A.eliminPerMin * step)
      mins = mins - step
    end
    if b.bac < 0.001 and b.pending < 0.001 then b.bac, b.pending = 0.0, 0.0 end
  end
  b.t = t
  return b
end

local function save(identifier, b)
  local t = now()
  local empty = b.bac <= 0 and b.pending <= 0
    and (b.thc.detectUntil or 0) <= t and (b.meth.detectUntil or 0) <= t
  if empty then
    DeleteResourceKvp(kvpKey(identifier))
  else
    SetResourceKvp(kvpKey(identifier), json.encode(b))
  end
end

-- ce trimitem clientului pentru efecte (secunde ramase, nu ore absolute: ceasurile difera)
local function snapshot(b)
  local t = now()
  return {
    bac = b.bac, pending = b.pending,
    absorb = A.absorbPerMin, elim = A.eliminPerMin,
    thcLeft = math.max(0, (b.thc.effectUntil or 0) - t), thcDoses = b.thc.doses or 0,
    methLeft = math.max(0, (b.meth.effectUntil or 0) - t), methDoses = b.meth.doses or 0,
    crashLeft = math.max(0, (b.meth.crashUntil or 0) - t),
  }
end

local function push(src, identifier)
  local b = advance(load(identifier))
  TriggerClientEvent('it_substante:state', src, snapshot(b))
end

-- ===== API pentru teste (server/teste.lua) =====
function SubBody(identifier)
  local b = advance(load(identifier))
  local t = now()
  return {
    bac = b.bac + 0.0,
    thc = (b.thc.detectUntil or 0) > t,
    meth = (b.meth.detectUntil or 0) > t,
  }
end

-- ===== consum =====
local function addDrug(b, kind, dose)
  local cfg, d, t = D[kind], b[kind], now()
  if (d.effectUntil or 0) > t then
    d.effectUntil = math.min(t + cfg.maxEffectMin * 60, d.effectUntil + cfg.extraPerDose * 60)
    d.doses = math.min(3, (d.doses or 1) + dose)
  else
    d.effectUntil = t + cfg.effectMin * 60
    d.doses = dose
  end
  d.detectUntil = t + cfg.detectMin * 60
  if cfg.crashMin then d.crashUntil = d.effectUntil + cfg.crashMin * 60 end
end

CreateThread(function()
  while not ESX or not ESX.RegisterUsableItem do Wait(250) end
  for name, it in pairs(Sub.Items) do
    ESX.RegisterUsableItem(name, function(src)
      local x = ESX.GetPlayerFromId(src)
      if not x then return end
      local item = x.getInventoryItem(name)
      if not item or (item.count or 0) < 1 then return end
      if pendingUse[src] and now() - pendingUse[src].at < 15 then return end
      pendingUse[src] = { item = name, at = now() }
      TriggerClientEvent('it_substante:consume', src, name)
    end)
  end
end)

-- clientul a terminat animatia (ok = true) sau a anulat (ok = false)
lib.callback.register('it_substante:consumed', function(src, name, ok)
  local p = pendingUse[src]
  pendingUse[src] = nil
  if not ok or not p or p.item ~= name or now() - p.at > 20 then return false end
  local it = Sub.Items[name]
  local x = ESX.GetPlayerFromId(src)
  if not it or not x then return false end
  local item = x.getInventoryItem(name)
  if not item or (item.count or 0) < 1 then return false end
  x.removeInventoryItem(name, 1)

  if it.kind == 'alcohol' or it.kind == 'drug' then
    local b = advance(load(x.identifier))
    if it.kind == 'alcohol' then
      b.pending = math.min(A.max, b.pending + it.bac)
    else
      addDrug(b, it.drug, it.dose or 1.0)
    end
    save(x.identifier, b)
    TriggerClientEvent('it_substante:state', src, snapshot(b))
  end
  return true
end)

-- la intrare + periodic (corecteaza deriva ceasului clientului) + salvare
AddEventHandler('esx:playerLoaded', function(src, x)
  if x and x.identifier then SetTimeout(4000, function() push(src, x.identifier) end) end
end)

CreateThread(function()
  while true do
    Wait(60000)
    for _, x in pairs(ESX.GetExtendedPlayers()) do
      local b = bodies[x.identifier]
      if b then
        advance(b)
        save(x.identifier, b)
        TriggerClientEvent('it_substante:state', x.source, snapshot(b))
      end
    end
  end
end)

AddEventHandler('playerDropped', function()
  local src = source
  pendingUse[src] = nil
  local x = ESX.GetPlayerFromId(src)
  if x and bodies[x.identifier] then
    save(x.identifier, advance(bodies[x.identifier]))
    bodies[x.identifier] = nil
  end
end)

AddEventHandler('onResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  SetTimeout(3000, function()
    for _, x in pairs(ESX.GetExtendedPlayers()) do push(x.source, x.identifier) end
  end)
end)

-- revive / spital: corpul ramane (substantele nu dispar la reanimare)
lib.callback.register('it_substante:myState', function(src)
  local x = ESX.GetPlayerFromId(src)
  if not x then return nil end
  return snapshot(advance(load(x.identifier)))
end)
