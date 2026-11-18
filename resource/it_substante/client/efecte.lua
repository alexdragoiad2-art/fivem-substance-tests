-- it_substante / client/efecte.lua - efectele alcoolului si drogurilor, din starea trimisa de server.
-- Nivelurile urmeaza alcoolemia reala (‰). Totul se aplica lin (intensitatea urca/coboara treptat),
-- iar la final tot ce s-a schimbat se reface (filtru, camera, mers, sunet, volan).

local st = nil          -- ultima stare de la server
local stAt = 0          -- GetGameTimer() la primire
local A = Sub.Alcohol

RegisterNetEvent('it_substante:state', function(s)
  st, stAt = s, GetGameTimer()
end)

-- alcoolemia acum (aceeasi formula ca pe server, pornind de la ultima stare)
local function bacNow()
  if not st then return 0.0 end
  local mins = (GetGameTimer() - stAt) / 60000.0
  local bac, pending = st.bac or 0.0, st.pending or 0.0
  while mins > 0 do
    local step = mins > 1 and 1 or mins
    local a = math.min(pending, (st.absorb or A.absorbPerMin) * step)
    pending = pending - a
    bac = math.max(0.0, bac + a - (st.elim or A.eliminPerMin) * step)
    mins = mins - step
  end
  return bac
end

local function left(key)
  if not st then return 0 end
  return math.max(0, (st[key] or 0) - (GetGameTimer() - stAt) / 1000.0)
end

-- ===== starea aplicata (ca sa nu reaplicam in fiecare cadru si sa putem reface exact) =====
local applied = { tc = nil, clip = nil, shake = nil, drunk = false, audio = false, sprint = 1.0, blur = false }
local smooth = 0.0       -- intensitatea vizuala, urca/coboara lin
local lastStumble, lastVomit, lastBlackout, lastWobble, lastMunch, lastStamina = 0, 0, 0, 0, 0, 0
local lastTier = 0
local TIER_MSG = {
  'Simți căldura alcoolului.',
  'Ești amețit. Mersul nu mai e tocmai drept.',
  'Ești băut. Reflexele îți sunt încetinite - nu conduce.',
  'Ești foarte beat. Abia te mai ții pe picioare.',
  'Ești criță. Ți se face rău.',
}

local function loadClip(clip)
  RequestAnimSet(clip)
  local t = GetGameTimer() + 1500
  while not HasAnimSetLoaded(clip) and GetGameTimer() < t do Wait(0) end
end

local function setClip(ped, clip)
  if applied.clip == clip then return end
  if clip then
    loadClip(clip)
    SetPedMovementClipset(ped, clip, 1.0)
  else
    ResetPedMovementClipset(ped, 1.0)
  end
  applied.clip = clip
end

local function setTimecycle(name)
  if applied.tc == name then return end
  if name then SetTimecycleModifier(name) else ClearTimecycleModifier() end
  applied.tc = name
end

local function setShake(name, amp)
  if not name then
    if applied.shake then StopGameplayCamShaking(true) end
    applied.shake = nil
    return
  end
  if applied.shake ~= name then
    if applied.shake then StopGameplayCamShaking(true) end
    ShakeGameplayCam(name, amp)
    applied.shake = name
  end
  SetGameplayCamShakeAmplitude(amp)
end

local function resetAll()
  local ped = PlayerPedId()
  setTimecycle(nil)
  setShake(nil)
  setClip(ped, nil)
  if applied.drunk then SetPedIsDrunk(ped, false) applied.drunk = false end
  if applied.blur then SetPedMotionBlur(ped, false) applied.blur = false end
  if applied.audio then SetAudioSpecialEffectMode(0) applied.audio = false end
  if applied.sprint ~= 1.0 then SetRunSprintMultiplierForPlayer(PlayerId(), 1.0) applied.sprint = 1.0 end
  smooth = 0.0
end

local function anim(ped, dict, clip, ms, flag)
  RequestAnimDict(dict)
  local t = GetGameTimer() + 1500
  while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
  TaskPlayAnim(ped, dict, clip, 4.0, -4.0, ms, flag or 0, 0.0, false, false, false)
end

-- ===== bucla principala =====
CreateThread(function()
  while true do
    local bac = bacNow()
    local thc, meth, crash = left('thcLeft'), left('methLeft'), left('crashLeft')
    local active = bac >= A.tiers[1] or thc > 0 or meth > 0 or crash > 0

    if not active then
      lastTier = 0
      if applied.tc or applied.shake or applied.clip or applied.drunk or applied.audio or applied.sprint ~= 1.0 then resetAll() end
      Wait(1000)
    else
      Wait(0)
      local ped, pid = PlayerPedId(), PlayerId()
      local t = GetGameTimer()
      local inVeh = IsPedInAnyVehicle(ped, false)
      local dead = IsEntityDead(ped)

      -- ---- mesaj cand urci la un nivel nou (ce simte personajul) ----
      local tier = 0
      for i, v in ipairs(A.tiers) do if bac >= v then tier = i end end
      if tier > lastTier then
        local msg = TIER_MSG[tier]
        if msg then ESX.ShowNotification(msg, 'info') end
      end
      lastTier = tier

      -- ---- tinta de intensitate (0..1) pentru alcool ----
      local alc = 0.0
      if bac >= A.tiers[1] then alc = math.min(1.0, (bac - A.tiers[1]) / (A.tiers[5] - A.tiers[1])) end
      local thcI = 0.0
      if thc > 0 then
        local doses = math.max(1, st.thcDoses or 1)
        thcI = math.min(1.0, 0.35 * doses)
        if thc < 60 then thcI = thcI * (thc / 60) end              -- se stinge in ultimul minut
      end
      local target = math.max(alc, thcI * 0.8, meth > 0 and 0.35 or 0, crash > 0 and 0.4 or 0)
      smooth = smooth + (target - smooth) * 0.01                  -- ~3-4 s pana la tinta

      -- ---- filtru de imagine (unul singur, cel dominant) ----
      if bac >= A.tiers[1] and alc >= thcI then
        setTimecycle('Drunk')
        SetTimecycleModifierStrength(0.32 + smooth * 0.6)   -- vizibil inca de la 0.2‰
      elseif thc > 0 then
        setTimecycle('drug_drive_blend01')
        SetTimecycleModifierStrength(0.25 + smooth * 0.55)
      elseif meth > 0 then
        setTimecycle('spectator5')
        SetTimecycleModifierStrength(0.25 + smooth * 0.3)
      elseif crash > 0 then
        setTimecycle('hud_def_desat_Neutral')
        SetTimecycleModifierStrength(0.35 + smooth * 0.4)
      end

      -- ---- camera ----
      if bac >= A.tiers[1] or thc > 0 then
        setShake('DRUNK_SHAKE', 0.45 + smooth * 1.9)
      elseif meth > 0 then
        setShake('HAND_SHAKE', 0.45)
      else
        setShake(nil)
      end

      -- ---- mers ----
      if not dead then
        local clip = nil
        if bac >= A.tiers[4] then clip = 'move_m@drunk@verydrunk'
        elseif bac >= A.tiers[3] then clip = 'move_m@drunk@moderatedrunk'
        elseif bac >= A.tiers[2] then clip = 'move_m@drunk@slightlydrunk'
        elseif thc > 0 and (st.thcDoses or 1) >= 2 then clip = 'move_m@drunk@slightlydrunk'
        elseif crash > 0 then clip = 'move_m@depressed@a' end
        setClip(ped, clip)
      end

      local drunkPed = bac >= A.tiers[2]
      if drunkPed ~= applied.drunk then SetPedIsDrunk(ped, drunkPed) applied.drunk = drunkPed end
      local blur = bac >= A.tiers[2] or thc > 0
      if blur ~= applied.blur then SetPedMotionBlur(ped, blur) applied.blur = blur end
      local audio = bac >= A.tiers[3]
      if audio ~= applied.audio then SetAudioSpecialEffectMode(audio and 2 or 0) applied.audio = audio end

      -- ---- meth: energie, apoi oboseala ----
      local sprint = meth > 0 and 1.15 or 1.0
      if sprint ~= applied.sprint then SetRunSprintMultiplierForPlayer(pid, sprint) applied.sprint = sprint end
      if meth > 0 and t - lastStamina > 2000 then lastStamina = t RestorePlayerStamina(pid, 1.0) end
      if crash > 0 then DisableControlAction(0, 21, true) end    -- epuizat: nu poate sprinta

      -- ---- THC: pofta de mancare ----
      if thc > 0 and t - lastMunch > 15000 then
        lastMunch = t
        TriggerEvent('esx_status:remove', 'hunger', 6000)
      end

      -- ---- alcool: volanul trage, impiedicari, voma, lesin ----
      if inVeh and bac >= A.tiers[3] and t - lastWobble > math.random(1800, 4200) then
        lastWobble = t
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) == ped and GetEntitySpeed(veh) > 3.0 then
          local force = (0.08 + smooth * 0.22) * (math.random() < 0.5 and -1 or 1)
          CreateThread(function()
            local stop = GetGameTimer() + math.random(350, 700)
            while GetGameTimer() < stop and DoesEntityExist(veh) do
              SetVehicleSteerBias(veh, force)
              Wait(0)
            end
            if DoesEntityExist(veh) then SetVehicleSteerBias(veh, 0.0) end
          end)
        end
      end

      if not inVeh and not dead and bac >= A.tiers[4] and IsPedRunning(ped) and t - lastStumble > 4000 then
        lastStumble = t
        if math.random() < 0.15 then SetPedToRagdoll(ped, 1500, 2500, 3, false, false, false) end
      end

      if not inVeh and not dead and bac >= 2.0 and t - lastVomit > 90000 then
        lastVomit = t
        if math.random() < 0.35 then
          anim(ped, 'oddjobs@taxi@tie', 'vomit_outside', 6000, 0)
          TriggerEvent('esx_status:remove', 'thirst', 60000)
        end
      end

      if bac >= A.blackout and not dead and t - lastBlackout > 300000 then
        lastBlackout = t
        CreateThread(function()
          DoScreenFadeOut(1500)
          Wait(1600)
          SetPedToRagdoll(PlayerPedId(), 18000, 20000, 0, false, false, false)
          Wait(15000)
          DoScreenFadeIn(2500)
        end)
      end
    end
  end
end)

-- stare la pornirea resursei / dupa respawn
CreateThread(function()
  while not ESX.IsPlayerLoaded() do Wait(1000) end
  Wait(3000)
  local s = lib.callback.await('it_substante:myState', false)
  if s then st, stAt = s, GetGameTimer() end
end)

AddEventHandler('esx:onPlayerSpawn', function()
  applied.clip = nil -- dupa respawn ped-ul e nou: reaplicam mersul
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then resetAll() end
end)

exports('GetBac', bacNow)
