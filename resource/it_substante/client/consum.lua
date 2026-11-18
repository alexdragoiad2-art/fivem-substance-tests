-- it_substante / client/consum.lua - animatia de consum (cu obiectul in mana), apoi confirmarea la server.

local ANIMS = {
  eat    = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', ms = 5000, label = 'Mănânci',
             bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) },
  drink  = { dict = 'mp_player_intdrink', clip = 'loop_bottle', ms = 4000, label = 'Bei',
             bone = 18905, pos = vec3(0.12, 0.008, 0.03), rot = vec3(240.0, -60.0, 0.0) },
  bottle = { dict = 'mp_player_intdrink', clip = 'loop_bottle', ms = 6000, label = 'Bei',
             bone = 18905, pos = vec3(0.12, 0.008, 0.03), rot = vec3(240.0, -60.0, 0.0) },
  glass  = { dict = 'mp_player_intdrink', clip = 'loop_bottle', ms = 5000, label = 'Bei',
             bone = 18905, pos = vec3(0.10, -0.02, 0.06), rot = vec3(240.0, -60.0, 0.0) },
  joint  = { dict = 'amb@world_human_smoking@male@male_a@idle_a', clip = 'idle_c', ms = 9000, label = 'Fumezi',
             bone = 47419, pos = vec3(0.015, -0.009, 0.003), rot = vec3(55.0, 0.0, 110.0) },
  pipe   = { dict = 'switch@trevor@trev_smoking_meth', clip = 'trev_smoking_meth_loop', ms = 7000, label = 'Fumezi',
             bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
}

local busy = false

RegisterNetEvent('it_substante:consume', function(name)
  local it = Sub.Items[name]
  if not it then return end
  if busy then
    lib.callback.await('it_substante:consumed', false, name, false)
    return
  end
  busy = true
  local a = ANIMS[it.anim] or ANIMS.eat
  local ok = lib.progressCircle({
    duration = a.ms,
    label = ('%s %s...'):format(a.label, it.label),
    position = 'bottom',
    useWhileDead = false,
    canCancel = true,
    disable = { combat = true, sprint = true },
    anim = { dict = a.dict, clip = a.clip, flag = 49 },
    prop = { model = it.prop, bone = a.bone, pos = a.pos, rot = a.rot },
  })
  local done = lib.callback.await('it_substante:consumed', false, name, ok == true)
  busy = false
  if not done then return end

  if it.hunger then TriggerEvent('esx_status:add', 'hunger', it.hunger) end
  if it.thirst then TriggerEvent('esx_status:add', 'thirst', it.thirst) end
end)
