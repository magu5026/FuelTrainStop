TrainIgnoreList={
"electric-locomotive",
"electric-locomotive-mk2",
"electric-locomotive-mk3",
"fusion-locomotive",
"fusion-locomotive-mk2",
"fusion-locomotive-mk3",
"hybrid-train",
"electric-vehicles-electric-locomotive"
}

local MODNAME="FuelTrainStop"

function Contains(tab,element)
	for _,v in pairs(tab) do
		if v == element then return true end
	end
	return false
end

function ONLOAD()
	init()
	getEnergyList()
	getTrainList()
end

function init()
	global.FuelTrainStop = global.FuelTrainStop or {}
	global.FuelTrainStop.TrainStop = global.FuelTrainStop.TrainStop or {}
	global.FuelTrainStop.FinishTrain = global.FuelTrainStop.FinishTrain or {}
	global.FuelTrainStop.EnergyList = global.FuelTrainStop.EnergyList or {}
	global.FuelTrainStop.TrainList = global.FuelTrainStop.TrainList or {}
	global.FuelTrainStop.BackerName = global.FuelTrainStop.BackerName or "Fuel Stop"
	for _,force in pairs(game.forces) do
		for _,tech in pairs(force.technologies) do
			if tech.name == "automated-rail-transportation" then
				if not tech.enabled then
					tech.enabled = true
				end
				if tech.researched then
					tech.researched = false
					tech.researched = true
				end
				break
			end
		end
	end
end

function getEnergyList()
	global.FuelTrainStop.EnergyList = {}
	local locs = game.surfaces[1].find_entities_filtered{type="locomotive"}
	local fuel_category = {}
	for _,loc in pairs(locs) do
		if loc.burner then
			if not Contains(fuel_category,loc.burner.fuel_category) then
				table.insert(fuel_category,loc.burner.fuel_category)
			end
		end
	end
	for _,item in pairs(game.item_prototypes) do
		if item.fuel_category then
			if Contains(fuel_category,item.fuel_category) then
				table.insert(global.FuelTrainStop.EnergyList,{name=item.name,fuel_value=item.fuel_value})
			end
		end
	end
end

function getTrainList()
	global.FuelTrainStop.TrainList = {}
	local alltrain = game.surfaces[1].get_trains()
	for _,train in pairs(alltrain) do
		table.insert(global.FuelTrainStop.TrainList,train)
	end
end

function ONCONFIG(data)
	init()
	getEnergyList()
	if migration(data) then
		local old_version = versionformat(data.mod_changes[MODNAME].old_version)
		if old_version < "00.15.03" then
			global.FuelTrainStop.TrainStop = {}
			local TrainStop = game.surfaces[1].find_entities_filtered{name="fuel-train-stop"}
			if #TrainStop ~= 0 then
				global.FuelTrainStop.BackerName = TrainStop[1].backer_name
				for _,entity in pairs(TrainStop) do
					table.insert(global.FuelTrainStop.TrainStop, entity)
				end
			end
			getTrainList()
			for _,train in pairs(global.FuelTrainStop.TrainList) do
				local schedule = train.schedule
				if schedule.records[#schedule.records].station == global.FuelTrainStop.BackerName then
					table.remove(schedule.records,#schedule.records)
					if schedule.current > #schedule.records then
						schedule.current = 1
					end
					train.schedule = schedule
				end
			end
		end
	end
end	

function migration(data)
	if data and data.mod_changes and data.mod_changes[MODNAME] then
		if data.mod_changes[MODNAME].old_version then
			return true
		end
	end
	return false
end

function versionformat(version)
	return string.format("%02d.%02d.%02d", string.match(version, "(%d+).(%d+).(%d+)"))
end

function ONTICK(event)
fuelStopTick(event)
end

function fuelStopTick(event)
	if event.tick % 300 == 15 and #global.FuelTrainStop.TrainStop ~= 0 then
		for index,train in pairs(global.FuelTrainStop.TrainList) do
			if train then
				if train.manual_mode == false then
					local locs = train.locomotives
					for _,loc in pairs(locs.back_movers) do
						if Contains(TrainIgnoreList,loc.name) then goto continue end
					end
					for _,loc in pairs(locs.front_movers) do
						if Contains(TrainIgnoreList,loc.name) then goto continue end
					end
					for _,loc in pairs(locs.front_movers) do
						local loc_inv = loc.get_fuel_inventory()
						local contents = loc_inv.get_contents()
						if getEnergy(contents) < (loc.prototype.max_energy_usage * 10000) then	-- 10000 ticks ~ 3 min
							addFuelSchedule(train)
							goto continue
						end
					end
					removeFuelSchedule(train)
				end
			else
				table.remove(global.FuelTrainStop.TrainList,index)
			end
			::continue::
		end
	end
end

function getEnergy(list)
	local e = 0
	for name,amount in pairs(list) do
		for _,item in pairs(global.FuelTrainStop.EnergyList) do
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
	if schedule.records[#schedule.records].station == global.FuelTrainStop.BackerName then return end
	local record = {station = global.FuelTrainStop.BackerName, wait_conditions = {}}
	record.wait_conditions[#record.wait_conditions+1] = {type = "inactivity", compare_type = "and", ticks = 120 }
	schedule.records[#schedule.records+1] = record
	train.schedule = schedule
	table.insert(global.FuelTrainStop.FinishTrain,train)
end

function removeFuelSchedule(train)
	for index,ftrain in pairs(global.FuelTrainStop.FinishTrain) do
		if ftrain == train then
			if not train.station or train.station.name ~= "fuel-train-stop" then
				local schedule = train.schedule
				table.remove(schedule.records,#schedule.records)
				if schedule.current > #schedule.records then
					schedule.current = 1
				end
				train.schedule = schedule
				table.remove(global.FuelTrainStop.FinishTrain,index)
				break
			end
		end
	end					
end

function ONBUILT(event)
	local entity = event.created_entity
	if entity.name == "fuel-train-stop" then
		table.insert(global.FuelTrainStop.TrainStop,entity)
		entity.backer_name = global.FuelTrainStop.BackerName
	end
end

function ONREMOVE(event)
	local entity = event.entity
	if entity.name == "fuel-train-stop" then
		for index,t_stop in pairs(global.FuelTrainStop.TrainStop) do
			if entity == t_stop then
				table.remove(global.FuelTrainStop.TrainStop,index)
			end
		end
	end
end

function ONRENAMED(event)
	if not event.by_script and event.entity.name == "fuel-train-stop" then
		global.FuelTrainStop.BackerName = event.entity.backer_name
		for _,t_stop in pairs(global.FuelTrainStop.TrainStop) do
			t_stop.backer_name = global.FuelTrainStop.BackerName			
		end
	end
end

function ONNEWTRAIN(event)
	local train = event.train
	if not Contains(global.FuelTrainStop.TrainList,train) then
		table.insert(global.FuelTrainStop.TrainList,train)
	end
end

script.on_configuration_changed(function(data) ONCONFIG(data) end)
script.on_init(function() ONLOAD() end)
script.on_event(defines.events.on_tick,ONTICK)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity},ONBUILT)
script.on_event({defines.events.on_preplayer_mined_item,defines.events.on_robot_pre_mined,defines.events.on_entity_died},ONREMOVE)
script.on_event(defines.events.on_entity_renamed,ONRENAMED)
script.on_event(defines.events.on_train_created,ONNEWTRAIN)