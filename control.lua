require("lua.basic_event_handler")
require("lua.logic_event_handler")


-- basic_event_handler
---------------------------------------------------------------------------------------------------

script.on_init(OnInit)
script.on_configuration_changed(OnConfigurationChanged)


-- logic_event_handler
---------------------------------------------------------------------------------------------------

script.on_nth_tick(1200,OnTick1200)
script.on_nth_tick(300,OnTick300)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,defines.events.script_raised_built},OnBuilt)
script.on_event({defines.events.on_pre_player_mined_item,defines.events.on_robot_pre_mined,defines.events.on_entity_died,defines.events.script_raised_destroy},OnRemove)
script.on_event(defines.events.on_entity_renamed,OnEntityRenamed)
script.on_event(defines.events.on_train_created,OnTrainCreated)
script.on_event(defines.events.on_train_changed_state,OnTrainChangedState)