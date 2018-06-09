local FUEL_TRAIN_STOP_NAME = "Fuel Stop"

TrainIgnoreList={
"electric-locomotive",
"electric-locomotive-mk2",
"electric-locomotive-mk3",
"fusion-locomotive",
"fusion-locomotive-mk2",
"fusion-locomotive-mk3"
}

function Contains(tab,element)
	for _,v in pairs(tab) do
		if v == element then return true end
	end
	return false
end

function ONLOAD()
	global.FuelTrainStop = global.FuelTrainStop or {}
	global.FinishTrain = global.FinishTrain or {}
	for _,force in pairs(game.forces) do
		for _,tech in pairs(force.technologies) do
			if tech.name == "automated-rail-transportation" and tech.researched then
				tech.researched = false
				tech.researched = true
				break
			end
		end
	end
end

function getEnergy(list)
	local e = 0
	for name,amount in pairs(list) do
		for _,item in pairs(game.item_prototypes) do
			if item.name == name then
			e = e + (item.fuel_value * amount) 
			break
			end
		end	
	end
	return e
end

function  addFuelSchedule(train)
	local schedule = train.schedule
	if schedule.records[#schedule.records].station == FUEL_TRAIN_STOP_NAME then return end
	local record = {station = FUEL_TRAIN_STOP_NAME, wait_conditions = {}}
	record.wait_conditions[#record.wait_conditions+1] = {type = "inactivity", compare_type = "and", ticks = 120 }
	schedule.records[#schedule.records+1] = record
	train.schedule = schedule
	table.insert(global.FinishTrain,train)
end

function removeFuelSchedule(train)
	for index,ftrain in pairs(global.FinishTrain) do
		if ftrain == train then
			if train.station == nil or train.station.name ~= "fuel-train-stop" then
				local schedule = train.schedule
				table.remove(schedule.records,#schedule.records)
				if schedule.current > #schedule.records then
					schedule.current = 1
				end
				train.schedule = schedule
				table.remove(global.FinishTrain,index)
			end
		end
	end					
end

function getTrains()
	local alltrain = game.surfaces[1].get_trains()
	local trainlist = {}
	for _,train in pairs(alltrain) do
		if train.manual_mode == false then
			local locs = train.locomotives
			for _,loc in pairs(locs.front_movers) do
				if Contains(TrainIgnoreList,loc.name) then goto continue end
			end
			for _,loc in pairs(locs.back_movers) do
				if Contains(TrainIgnoreList,loc.name) then goto continue end
			end
			table.insert(trainlist,train)
		end
		::continue::
	end
	return trainlist
end

function ONTICK(event)
	if event.tick % 300 ~= 15 and #global.FuelTrainStop == 0 then return end
	local trainlist = getTrains()
	for _,train in pairs(trainlist) do
		local locs = train.locomotives
		local f_locs = locs.front_movers
		for _,loc in pairs(f_locs) do
			local train_fuel = loc.get_fuel_inventory()
			local contents = train_fuel.get_contents()
			if getEnergy(contents) < (loc.prototype.max_energy_usage * 10000) then	-- 10000 ticks ~ 3 min
				addFuelSchedule(train)
				goto continue
			end
		end
		removeFuelSchedule(train)
		::continue::
	end
end


function ONBUILT(event)
	local entity = event.created_entity
	if entity.name == "fuel-train-stop" then
		table.insert(global.FuelTrainStop, entity)
		entity.backer_name = FUEL_TRAIN_STOP_NAME
	end
end


function ONREMOVE(event)
	local entity = event.entity
	if entity.name == "fuel-train-stop" then
		for index,t_stop in pairs(global.FuelTrainStop) do
			if entity == t_stop then
				table.remove(global.FuelTrainStop,index)
			end
		end
	end
end


function ONRENAMED(event)
	if not event.by_script and event.entity.name == "fuel-train-stop" then
		FUEL_TRAIN_STOP_NAME = event.entity.backer_name
		for _,t_stop in pairs(global.FuelTrainStop) do
			t_stop.backer_name = FUEL_TRAIN_STOP_NAME			
		end
	end
end


script.on_configuration_changed(function(data)
	if data and data.mod_changes['FuelTrainStop'] then
		ONLOAD()		
	end
end)
script.on_init(function() ONLOAD() end)

script.on_event(defines.events.on_tick,ONTICK)
script.on_event(defines.events.on_built_entity,ONBUILT)
script.on_event(defines.events.on_robot_built_entity,ONBUILT)
script.on_event(defines.events.on_preplayer_mined_item,ONREMOVE)
script.on_event(defines.events.on_robot_mined_entity,ONREMOVE)
script.on_event(defines.events.on_entity_died,ONREMOVE)
script.on_event(defines.events.on_entity_renamed,ONRENAMED)