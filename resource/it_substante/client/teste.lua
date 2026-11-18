-- it_substante / client/teste.lua - acordul persoanei, animatiile cu aparatul in mana si afisajul aparatului (NUI).

local PROPS = {
  alcool  = { model = 'it_etilotest', fallback = 'prop_cs_hand_radio', bone = 28422, pos = vec3(0.04, 0.02, -0.02), rot = vec3(-80.0, 0.0, 10.0) },
  droguri = { model = 'it_drugtest',  fallback = 'prop_cs_business_card', bone = 28422, pos = vec3(0.05, 0.02, -0.01), rot = vec3(-90.0, 0.0, 0.0) },
}

local held = nil

local function dropProp()
  if held and DoesEntityExist(held) then DeleteEntity(held) end
  held = nil
end

local function holdProp(kind)
  dropProp()
  local p = PROPS[kind]
  local model = IsModelInCdimage(joaat(p.model)) and p.model or p.fallback
  local hash = lib.requestModel(model, 3000)
  if not hash then return end
  local ped = PlayerPedId()
  local c = GetEntityCoords(ped)
  held = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
  SetEntityCollision(held, false, false)
  AttachEntityToEntity(held, ped, GetPedBoneIndex(ped, p.bone), p.pos.x, p.pos.y, p.pos.z, p.rot.x, p.rot.y, p.rot.z, true, true, false, true, 1, true)
  SetModelAsNoLongerNeeded(hash)
end

local function playAnim(dict, clip, flag, ms)
  if not lib.requestAnimDict(dict, 3000) then return end
  TaskPlayAnim(PlayerPedId(), dict, clip, 3.0, -3.0, ms or -1, flag or 49, 0.0, false, false, false)
end

-- ===== acordul =====
local consentOpen = false
RegisterNetEvent('it_substante:consent', function(d)
  consentOpen = true
  local what = d.kind == 'alcool' and 'testarea alcoolscopică (etilotest)'
    or d.kind == 'sange' and 'recoltarea de probe biologice (sânge) pentru analiza toxicologică'
    or 'testarea antidrog (test salivar)'
  local res = lib.alertDialog({
    header = 'Poliția Română',
    content = ('Agentul **%s** îți solicită %s.\n\nRefuzul testării este **infracțiune** (art. 337 C. pen.).\n\nAi %d secunde să răspunzi.'):format(d.officer or '', what, d.seconds or 25),
    centered = true,
    cancel = true,
    labels = { confirm = 'Accept testarea', cancel = 'Refuz' },
  })
  if not consentOpen then return end -- s-a inchis la expirare
  consentOpen = false
  TriggerServerEvent('it_substante:consentReply', d.token, res == 'confirm')
end)

RegisterNetEvent('it_substante:consentClose', function()
  if consentOpen then consentOpen = false lib.closeAlertDialog() end
end)

-- ===== testul =====
RegisterNetEvent('it_substante:testStart', function(d)
  local ped = PlayerPedId()
  if d.other and d.other ~= GetPlayerServerId(PlayerId()) then
    local otherPed = GetPlayerPed(GetPlayerFromServerId(d.other))
    if otherPed ~= 0 then TaskTurnPedToFaceEntity(ped, otherPed, 1200) Wait(900) end
  end

  if d.role == 'officer' then
    holdProp(d.kind)
    if d.kind == 'alcool' then
      playAnim('cellphone@', 'cellphone_text_read_base', 49)
    else
      playAnim('mp_common', 'givetake1_a', 48, 1500)
      Wait(1500)
      playAnim('cellphone@', 'cellphone_text_read_base', 49)
    end
  else
    if d.kind == 'alcool' then
      playAnim('mp_facial', 'mic_chatter', 49) -- sufla in aparat
    else
      playAnim('mp_common', 'givetake1_b', 48, 1500)
    end
  end

  SendNUIMessage({ action = 'start', kind = d.kind, role = d.role, seconds = d.seconds, name = d.name })
end)

local function endTest()
  ClearPedSecondaryTask(PlayerPedId())
  dropProp()
end

RegisterNetEvent('it_substante:testResult', function(res)
  SendNUIMessage({ action = 'result', res = res })
  SetTimeout(1500, endTest)
end)

RegisterNetEvent('it_substante:testAbort', function(msg)
  SendNUIMessage({ action = 'abort', msg = msg })
  ESX.ShowNotification(msg, 'error')
  endTest()
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then dropProp() end
end)

-- ===== recoltare probe biologice (ALT pe persoana) =====
local function canTox()
  local j = (ESX.GetPlayerData() or {}).job
  if not j then return false end
  if j.name == Sub.Tox.medicJob then return true end
  return j.name == Sub.Police.job and j.onDuty == true
end

local function collectTox(entity)
  local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
  ESX.ShowNotification('Ai cerut acordul pentru recoltare. Se așteaptă răspunsul...')
  local ok, tokenOrMsg = lib.callback.await('it_substante:toxRequest', false, target)
  if not ok then
    if tokenOrMsg then ESX.ShowNotification(tokenOrMsg, 'error') end
    return
  end
  if lib.progressCircle({
    duration = Sub.Tox.ms, label = 'Recoltezi proba de sânge...', position = 'bottom', canCancel = true,
    disable = { move = true, car = true, combat = true },
    anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 },
    prop = { model = 'prop_syringe_01', bone = 6286, pos = vec3(0.04, 0.04, 0.0), rot = vec3(125.44, 0.0, 0.0) },
  }) then
    local done, msg = lib.callback.await('it_substante:toxCollect', false, target, tokenOrMsg)
    if msg then ESX.ShowNotification(msg, done and 'success' or 'error') end
  end
end

CreateThread(function()
  while GetResourceState('ox_target') ~= 'started' do Wait(500) end
  exports.ox_target:addGlobalPlayer({
    {
      name = 'it_substante_tox',
      icon = 'fas fa-syringe',
      label = 'Recoltează sânge (toxicologie)',
      distance = 2.0,
      canInteract = function() return canTox() end,
      onSelect = function(data) collectTox(data.entity) end,
    },
  })
end)
