-- What: The battery's suite list — every test_*.lua the quester battery must run.
-- When: Read by tests/test_runner_lib.lua during discovery, before any suite runs.
-- Why: Discovery used to fall back to a hand-kept list when luafilesystem was
--      missing, and that list named fewer suites than the directory held — so the
--      runner could print a green total over a partial battery. Discovery is now
--      lfs-only and cross-checked against this manifest in BOTH directions: a suite
--      on disk but absent here, or listed here but absent on disk, aborts the run.
--      Adding a suite means adding it here too, or the run refuses to start.
-- Safety: data only — no requires, no side effects, no state.

return {
    names = {
        "test_auto_equip.lua",
        "test_class_faction_filter.lua",
        "test_combat_helper.lua",
        "test_confirm_inputs.lua",
        "test_coordinator.lua",
        "test_dead_state.lua",
        "test_death_tracker.lua",
        "test_diagnostic_dump.lua",
        "test_do_action_state.lua",
        "test_dungeon_detector.lua",
        "test_flight_path.lua",
        "test_frame_event_parity.lua",
        "test_global_hygiene.lua",
        "test_goal_resolver.lua",
        "test_idle_state.lua",
        "test_integration_death_flow.lua",
        "test_integration_quest_flow.lua",
        "test_integration_vendor_flow.lua",
        "test_interact_state.lua",
        "test_loot_manager.lua",
        "test_lua51_compat.lua",
        "test_mount_manager.lua",
        "test_nav_client_contract.lua",
        "test_nav_client_parity.lua",
        "test_nav_state.lua",
        "test_no_quest_abandon.lua",
        "test_npc_db.lua",
        "test_npc_manager.lua",
        "test_object_scanner.lua",
        "test_pre_accept_all.lua",
        "test_progress_tracker.lua",
        "test_quest_blacklist.lua",
        "test_quest_frame_events.lua",
        "test_respawn_wait.lua",
        "test_runner_discovery.lua",
        "test_runner_lib.lua",
        "test_safe_api_wrapper.lua",
        "test_service_gossip.lua",
        "test_state_machine_ownership.lua",
        "test_static_popup.lua",
        "test_step_lookahead.lua",
        "test_tick_allocation.lua",
        "test_transport_helper.lua",
        "test_utils_sylvanas.lua",
        "test_vendor_bag_trigger.lua",
        "test_vendor_manager.lua",
        "test_waiting_state.lua",
        "test_waypoint_fixer.lua",
    },
}
