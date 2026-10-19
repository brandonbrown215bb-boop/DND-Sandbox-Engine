class_name BatchQControls
extends RefCounted

static func answer(h: Node, combat: Node, title_part: String, text_part: String = "", cancel: bool = false) -> bool:
	for _frame in 150:
		await h.get_tree().process_frame
		var popup: PopupMenu = h._find_visible_exchange_popup(combat,title_part)
		if popup == null: continue
		if cancel:
			popup.hide()
			return true
		for index in popup.item_count:
			if popup.get_item_text(index).contains(text_part):
				popup.id_pressed.emit(popup.get_item_id(index))
				return true
		return false
	return false

static func run(h: Node) -> void:
	h._enter_test("batch_q_party_flow")
	h._setup_world()
	BatchQChecks.load_fixtures()
	while PlayerManager.get_player_count()<3: PlayerManager.add_player("Party recipient")
	for suffix in ["plain","changed"]:
		var giver := BatchQChecks.actor("q_control_giver_"+suffix,suffix)
		var a := BatchQChecks.actor("q_control_a_"+suffix,suffix,false)
		var b := BatchQChecks.actor("q_control_b_"+suffix,suffix,false)
		PartyManager.reset()
		var members: Array=[giver,a,b]
		for index in members.size():
			PlayerManager.set_player_character(index,members[index])
			PartyManager.register_player_character(index,members[index])
		var dummy: Dictionary=DataLoader.get_monster("goblin").duplicate(true)
		dummy.id="fixture:q_dummy"
		dummy.hit_points="1000"
		DataLoader.monsters[dummy.id]=dummy
		GameManager.transition_context={"terrain":"plains","monster_ids":[dummy.id]}
		GameManager.current_state=GameManager.GameState.COMBAT
		GameManager.test_mode=false
		FighterChecks._seed_die(20,20)
		var combat: Node=await h._spawn_scene("res://scenes/combat.tscn",0.8)
		h._p_focus(combat,giver)
		var events: Array=[]
		var listener:=func(details: Dictionary): events.append(details.duplicate(true))
		Dice.dice_rolled.connect(listener)
		var id:=BatchQChecks.fid("fixed_total",suffix)
		var before:=giver.to_dict().duplicate(true)
		h._assert(h._p_select(combat,id,id),"Q controls: Features/source opens fixed allocation "+suffix)
		h._assert(await answer(h,combat,"Allocate:",a.character_name),"Q controls: real first recipient "+suffix)
		h._assert(await answer(h,combat,"Choose amount","4"),"Q controls: real integer quantity "+suffix)
		h._assert(await answer(h,combat,"Allocate:","",true),"Q controls: cancel partial allocation "+suffix)
		await h.get_tree().process_frame
		h._assert(giver.to_dict()==before and combat.turn_budget.bonus_action_available and a.current_hp==1 and a.temp_hp==0 and events.is_empty() and not combat.resolving_player_action,"Q controls: canceled split is atomic "+suffix)
		h._p_select(combat,id,id)
		await answer(h,combat,"Allocate:",a.character_name)
		await answer(h,combat,"Choose amount","4")
		await answer(h,combat,"Allocate:",b.character_name)
		await answer(h,combat,"Choose amount","3")
		await answer(h,combat,"Allocate:","Confirm allocation")
		await h.get_tree().process_frame
		h._assert(combat.last_party_allocation.get("success",false) and combat.last_party_allocation.used==7 and giver.numeric_resource_pools[id].current==3 and not combat.turn_budget.bonus_action_available and events.is_empty(),"Q controls: fixed budget split through real controls pays once "+suffix)
		h._assert((a.current_hp==5 and b.current_hp==4) if suffix=="plain" else (a.temp_hp==4 and b.temp_hp==3),"Q controls: actual split HP/Temporary HP "+suffix)
		print("Q FIXED CONTROL RECEIPT: "+JSON.stringify(combat.last_party_allocation))
		# A revealed roll belongs to this paid activation even on cancel.
		h._p_focus(combat,giver)
		id=BatchQChecks.fid("rolled_total",suffix)
		var count:=events.size()
		h._assert(h._p_select(combat,id,id),"Q controls: rolled allocation opens "+suffix)
		h._assert(events.size()==count+1 and giver.numeric_resource_pools[id].current==3 and not combat.turn_budget.bonus_action_available,"Q controls: reveal captures and pays exactly once "+suffix)
		await answer(h,combat,"Allocate:","",true)
		await h.get_tree().process_frame
		h._assert(combat.last_party_allocation.get("forfeited",false) and giver.numeric_resource_pools[id].current==3 and events.size()==count+1,"Q controls: revealed cancel forfeits original use "+suffix)
		h._p_focus(combat,giver)
		FighterChecks._seed_die(6 if suffix=="plain" else 8,5)
		h._p_select(combat,id,id)
		await answer(h,combat,"Allocate:",a.character_name)
		await answer(h,combat,"Choose amount","2")
		await answer(h,combat,"Allocate:",b.character_name)
		await answer(h,combat,"Choose amount","3")
		await h.get_tree().process_frame
		h._assert(combat.last_party_allocation.get("success",false) and combat.last_party_allocation.total==5 and combat.last_party_allocation.used==5 and events.size()==count+2 and giver.numeric_resource_pools[id].current==2,"Q controls: single captured roll split among actual recipients "+suffix)
		print("Q ROLLED CONTROL RECEIPT: "+JSON.stringify(combat.last_party_allocation))
		# Select two non-prefix exact dice through their visible identity labels.
		h._p_focus(combat,giver)
		id=BatchQChecks.fid("captured_dice",suffix)
		var dice: Array=giver.numeric_resource_pools[id].captured_dice.duplicate(true)
		count=events.size()
		h._assert(h._p_select(combat,id,id),"Q controls: captured-dice allocator bypasses ordinary self-heal quantity menu "+suffix)
		await answer(h,combat,"Allocate:",a.character_name)
		await answer(h,combat,"Choose a retained die",str(dice[2].die_id))
		await answer(h,combat,"Allocate:",b.character_name)
		await answer(h,combat,"Choose a retained die",str(dice[0].die_id))
		await answer(h,combat,"Allocate:","Confirm allocation")
		await h.get_tree().process_frame
		h._assert(combat.last_party_allocation.get("success",false) and combat.last_party_allocation.results[0].allocated==dice[2].face and combat.last_party_allocation.results[1].allocated==dice[0].face and giver.numeric_resource_pools[id].captured_dice==[dice[1],dice[3]] and events.size()==count and not combat.turn_budget.bonus_action_available,"Q controls: selected dice distribute original faces without RNG or identity duplication "+suffix)
		print("Q DICE CONTROL RECEIPT: "+JSON.stringify(combat.last_party_allocation))
		# S-083 prerequisite: one transferred roll, two independent real attacks.
		h._p_focus(combat,giver)
		id=BatchQChecks.fid("gift",suffix)
		count=events.size()
		h._p_select(combat,id,id)
		await h._p_answer(combat,a)
		await h._p_answer(combat,b)
		await h.get_tree().process_frame
		h._assert(a.captured_grants.size()==1 and b.captured_grants.size()==1 and a.captured_grants[0].value==b.captured_grants[0].value and events.size()==count+1,"Q/S083 controls: one actual shared bonus transfer "+suffix)
		var shared_value: int=a.captured_grants[0].value
		giver.reaction_available=false
		for recipient in [a,b]:
			var gift: Dictionary=recipient.captured_grants[0].duplicate(true)
			var attack_result:=await _attack(h,combat,recipient,str(gift.grant_id),events)
			h._assert(attack_result.get("success",false) and recipient.captured_grants.is_empty() and not recipient.reaction_available and attack_result.get("bonus",0)==shared_value,"Q/S083 controls: recipient pays own Reaction for original face in actual Attack "+recipient.character_id)
		# S-097: helper retains its own source and Reaction off its turn.
		giver.reaction_available=true
		var help_id:=BatchQChecks.fid("help",suffix)
		var quantity_before: int=giver.numeric_resource_pools[help_id].current
		var help_result:=await _attack(h,combat,a,"party:",events,false,true)
		h._assert(help_result.get("success",false) and giver.numeric_resource_pools[help_id].current==quantity_before-1 and not giver.reaction_available and a.reaction_available and help_result.get("bonus",0)==int(giver.get_feature(help_id).roll_intervention.amount),"Q controls: off-turn helper alone pays Reaction/exact pool while attack keeps original action "+suffix)
		for entry in combat.player_entities:
			if entry.get("character")==giver: h._assert(not entry.reaction_available,"Q controls: helper entity Reaction mirror matches "+suffix)
		giver.reaction_available=true
		var stale_result:=await _attack(h,combat,a,"party:",events,true)
		h._assert(stale_result.get("success",false) and giver.reaction_available and giver.numeric_resource_pools[help_id].current==4,"Q controls: source reacquisition during chooser declines unchanged miss without helper payment "+suffix)
		Dice.dice_rolled.disconnect(listener)
		h._teardown_scene(combat)
		GameManager.test_mode=true
	DataLoader.load_all_data()
	h._exit_test()

static func _attack(h: Node, combat: Node, actor: Character, source_prefix: String, events: Array, stale: bool = false, extra: bool = false) -> Dictionary:
	h._p_focus(combat,actor)
	actor.extra_attacks=1 if extra else 0
	actor.inventory.equip(Inventory.Slot.WEAPON,"dagger",true)
	combat.player_entities[combat.current_player_idx].hex_position=Vector2i.ZERO
	for entry in combat.player_entities:
		if entry.get("character")!=actor: entry.hex_position=Vector2i(6,0)
	var target: Dictionary=combat.monster_entities[0]
	target.hex_position=Vector2i(1,0)
	target.armor_class=17 # natural 9 + DEX5 + proficiency2 is a captured miss by one.
	target.current_hp=1000
	combat._update_grid_entities()
	combat.hud.update_hud(actor,combat.tracker)
	var count:=events.size()
	FighterChecks._seed_die(20,9)
	combat.hud.btn_attack.pressed.emit()
	h._assert(combat.pending_action_type=="attack","Q controls: actual Attack button enters targeting "+actor.character_id)
	combat.call_deferred("_on_hex_clicked",Vector2i(1,0))
	var popup: PopupMenu=null
	for _frame in 180:
		await h.get_tree().process_frame
		popup=h._visible_weapon_attack_bonus_popup(combat.hud)
		if popup!=null: break
	h._assert(popup!=null,"Q controls: actual captured weapon choice "+actor.character_id)
	if popup==null: return {}
	var record: Dictionary=h._pending_weapon_attack_bonus_record_for_test(actor)
	var source: String=""
	var amount:=0
	for option in record.get("options",[]):
		if str(option.source_instance_id).begins_with(source_prefix):
			source=str(option.source_instance_id)
			amount=int(option.amount)
	var index: int=h._weapon_bonus_popup_index(record,source)
	h._assert(index>0,"Q controls: correct recipient/helper offered by canonical record "+actor.character_id)
	if index<=0:
		popup.hide()
		return {}
	var original_total: int=record.context.attack_result.total
	var request_id: String=record.request_id
	if stale:
		for option in record.options:
			if option.source_instance_id == source and option.has("pool_source"):
				ResourcePoolRules.remove(option.spender,str(option.pool_source))
				ResourcePoolRules.acquire(option.spender,option.feature_snapshot,str(option.pool_source))
	popup.id_pressed.emit(popup.get_item_id(index))
	for _frame in 180:
		await h.get_tree().process_frame
		if not combat.resolving_player_action: break
	var d20s:=0
	for event in events.slice(count):
		if int(event.get("sides",0))==20: d20s+=1
	var replay:=SpellDamageRolls.settle_weapon_attack_bonus(actor,target,{"weapon_attack_bonus_request":{"request_id":request_id}},source)
	h._assert(d20s==(2 if extra else 1) and not combat.turn_budget.action_available and (target.current_hp==1000 if stale else target.current_hp<1000) and not combat.resolving_player_action and replay.get("refused",false),"Q controls: original d20 per swing, one action/payment, completed replay refused "+actor.character_id)
	print("Q ATTACK CONTROL RECEIPT: "+JSON.stringify({"actor":actor.character_id,"source":source,"original_total":original_total,"bonus":amount,"target_ac":17,"hp_after":target.current_hp,"d20s":d20s,"reaction_available":actor.reaction_available,"action_available":combat.turn_budget.action_available}))
	actor.extra_attacks=0
	return {"success":d20s==(2 if extra else 1) and (target.current_hp==1000 if stale else target.current_hp<1000) and not combat.resolving_player_action,"bonus":amount}
