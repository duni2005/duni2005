class_name Phase11Fixture
extends RefCounted
## Explicit complex persistent state. No live combat frames in this fixture.
static func make() -> TowerController:
	var c:=TowerController.new();c.new_run(19,73);var run: RunState=c.guild.state
	run.run_id="run_phase11_fixture"
	for room in run.tower.map.rooms.values():room.source_run_id=run.run_id
	c.select_room("0:0");c.content_action(&"recruit",{"offer_id":c.current_room().recruit.offers[0].offer_id});c.return_map()
	c.select_room("0:1")
	var offer: ShopOffer=c.current_room().shop.offers[0];c.content_action(&"buy",{"offer_id":offer.offer_id});c.return_map()
	c.select_room("0:2");c.content_action(&"rest",{"choice":&"resources"})
	var members: Array[GuildMemberState]=c.guild.all_members();var a: GuildMemberState=members[0];var b: GuildMemberState=members[1]
	a.level=3;a.stars=1;a.current_hp=43;a.energy=2;a.ultimate_gauge=37;a.transcendence_gauge=48;a.stance=CombatStance.CAUTIOUS;a.fang_kills=7
	b.level=10;b.current_hp=0;b.energy=0;b.ultimate_gauge=11;b.transcendence_gauge=19;b.stance=CombatStance.COVER
	for kind in [&"vital",&"greenNecklace",&"fang"]:
		var item: ItemInstance=c.content.inventory.give(kind,"fixture:"+kind);item.equipped_to_member_id=a.member_id
	c.content.inventory.give(&"vital","fixture:duplicate")
	for pair in [[7,{"ammo":1,"reloadRemaining":2.7}],[10,{"lostSword":{"dx":90.0,"dy":-35.0,"vx":40.0,"vy":-10.0,"flight":.3,"rotation":.4,"sizeBoost":1.06,"scale":1.0},"guardStacks":2}],[12,{"predatorStacks":4}],[11,{"dolphinStacks":5,"curseTime":2.3}],[16,{"paladinSwings":3,"paladinBlessingTime":4.1}],[20,{"shockStacks":3}],[18,{"face":.7,"tankHeadingAngle":.9}],[25,{"shotsFired":2}],[15,{"satelliteBursts":[{"remaining":.16,"damage":2.8}]}]]:
		var member: GuildMemberState=c.guild.create_member(pair[0]);member.character_specific_state=pair[1]
	a.character_specific_state={"cooldown":.73,"shieldHp":44,"shieldTime":3.1,"parryCooldown":6.2,"stun":.4,"test_counter":3,"totemClock":2.1}
	for card in run.strategy_cards:card.used_depth=0;card.used_floors=[0];card.ready_floor=2
	run.strategy_cards[2].consumed=true;run.give_strategy_card(&"charge").ready_floor=3
	run.strategy_use_receipts["fixture-use"]={"card_id":run.strategy_cards[2].card_id,"kind":"shield"}
	run.last_formation.capture([DeploymentEntry.new(a.member_id,Vector2(180,400)),DeploymentEntry.new(b.member_id,Vector2(180,200))])
	var battle_room: RoomState=run.tower.map.get_room("0:3");battle_room.discovered=true;battle_room.visited=true;battle_room.battle_attempt_count=1;run.tower.visited_rooms[battle_room.room_id]=true
	var enemies: Array=battle_room.enemy_state.values();enemies[0].current_hp=0;enemies[1].current_hp=43;enemies[1].position=Vector2(465,310);enemies[1].ultimate_gauge=58
	enemies[1].persistent_state={"cooldown":.9,"shieldHp":40,"shieldTime":2,"parryCooldown":4,"stun":.7,"face":.4,"retreatRemaining":1.8,"specialRemaining":2.4,"ultCast":{"t":.2,"duration":.65,"target":"member:"+a.member_id,"angle":.4,"point":{"x":180.0,"y":400.0}},"puppetControl":{"owner":"member:"+run.guild_members.values().filter(func(m):return m.unit_type_id==25)[0].member_id,"remaining":2.0,"original_team":1,"team":0}}
	var control: Dictionary=enemies[1].persistent_state.puppetControl
	var cast_state: Dictionary=enemies[1].persistent_state;cast_state.erase("puppetControl");cast_state.erase("stun");enemies[1].persistent_state=cast_state
	enemies[2].persistent_state={"puppetControl":control,"stun":.7}
	battle_room.kill_rewards[enemies[0].enemy_id]={"gold":12,"tokens":0};battle_room.settled_result_ids["fixture-result"]=true;run.settled_battle_ids["fixture-result"]=true;run.tower.processed_results["fixture-result"]=true
	run.death_losses_by_result_id["fixture-result"]={b.member_id:5.0}
	# A completed floor and fulfilled item request are fixture data, not fake game rewards.
	for id in run.tower.map.floors[1].room_ids:
		var room: RoomState=run.tower.map.get_room(id);room.discovered=true;room.visited=true;room.cleared=true;room.consumed=room.room_type not in [RoomType.SHOP,RoomType.RECRUIT];run.tower.visited_rooms[id]=true
		for enemy in room.enemy_state.values():enemy.current_hp=0
	run.tower.map.floors[1].bonus=&"item";run.tower.map.floors[1].bonus_item_kind=&"chargeTotem";c.refresh_progress(1)
	var event: RoomState=run.tower.map.get_room("0:4");event.event_type=&"hotSpring";c.select_room(event.room_id)
	run.tower.map_scroll_y=321;return c
