extends Node

# Cross-system signal bus.

signal damage_dealt(source, target, amount, is_crit)
signal entity_killed(entity, killer)
signal loot_dropped(item, position)
signal item_picked_up(item)
signal player_leveled_up(new_level)
signal perk_chosen(perk_id)
signal weapon_evolved(from_id, to_id)
signal screen_shake(strength, duration)
signal hit_stop(duration)
signal floating_text(text, position, color)
signal potion_used(kind)
signal player_died()
signal boss_defeated(boss_id)
signal room_cleared(room_id)
signal currency_changed(kind, delta, total)

# World sim signals
signal day_night_phase_changed(phase)
signal weather_changed(kind)
signal world_event_started(event_id, payload)
signal world_event_ended(event_id)
signal hour_advanced(hour)

# Quest signals
signal quest_started(quest_id)
signal quest_objective_progress(quest_id, objective_id, current, target)
signal quest_completed(quest_id)
signal quest_pinned(quest_id)
signal lore_unlocked(entry_id)

# Travel signals
signal portal_unlocked(portal_id)
signal travel_started(destination)
signal travel_completed(destination)
signal bond_set(location_id)

# Buff signals
signal buff_applied(buff_id, source)
signal buff_expired(buff_id)
signal weapon_buff_applied(buff_id)

# Faction
signal faction_rep_changed(faction_id, delta, total)
signal faction_power_shifted(faction_id, delta, total)

# Music
signal music_layer_request(layer)
