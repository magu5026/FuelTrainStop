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
	for _,item in pairs(game.item_prototypes) do
		if item.fuel_category then
			table.insert(global.FuelTrainStop.EnergyList,{name=item.name,fuel_value=item.fuel_value})
		end
	end
end

function getTrainList()
	global.FuelTrainStop.TrainList = {}
	local alltrain = game.surfaces[1].get_trains()
	for _,train in pairs(alltrain) do	
		local locs = train.locomotives
		for _,loc in pairs(locs.front_movers) do
			if Contains(TrainIgnoreList,loc.name) then goto continue end
		end
		for _,loc in pairs(locs.back_movers) do
			if Contains(TrainIgnoreList,loc.name) then goto continue end
		end
		if Contains(global.FuelTrainStop.TrainList,train) then goto continue end
		table.insert(global.FuelTrainStop.TrainList,train)
		::continue::
	end
end

function ONCONFIG(data)
	init()
	getEnergyList()
	if migration(data) then
		local old_version = versionformat(data.mod_changes[MODNAME].old_version)
		if old_version < "00.15.03" then migration_0_15_3() end
		if old_version < "00.15.05" then migration_0_15_5() end
		if old_version == "00.15.06" then migration_0_15_7() end
	end
end	

function migration_0_15_3()
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

function migration_0_15_5()
	global.FuelTrainStop.FinishTrain = {}
	local alltrain = game.surfaces[1].get_trains()
	if #alltrain ~= 0 then
		for _,train in pairs(alltrain) do
			if train.station and train.station.backer_name == global.FuelTrainStop.BackerName then    
				table.insert(global.FuelTrainStop.FinishTrain, train)
			end
		end
	end
end

function migration_0_15_7()
	local backer_name = global.FuelTrainStop.BackerName or "Fuel Stop"
	global.FuelTrainStop = {}
	global.FuelTrainStop.TrainStop = {}
	global.FuelTrainStop.FinishTrain = {}
	global.FuelTrainStop.EnergyList = {}
	global.FuelTrainStop.TrainList = {}
	global.FuelTrainStop.BackerName = backer_name
	local train_stop = game.surfaces[1].find_entities_filtered{name="fuel-train-stop"}
	global.FuelTrainStop.TrainStop = train_stop
	getEnergyList()
	getTrainList()
	local alltrains = game.surfaces[1].get_trains()	
	for _,train in pairs(alltrains) do
		local schedule = train.schedule
		if schedule then
			for i,record in pairs(schedule.records) do
				if record.station == global.FuelTrainStop.BackerName then
					table.remove(schedule.records,i)
					if i > #schedule.records then
						schedule.current = 1
					else
						schedule.current = i
					end					
					break
				end
			end
			train.schedule = schedule
		end
	end
end

function ONTICK(event)
	addFuelSchedule(event)
	removeFuelSchedule(event)
end

function addFuelSchedule(event)
	if not (event.tick % 1200 == 15 and #global.FuelTrainStop.TrainStop > 0) then return end
	for index,train in pairs(global.FuelTrainStop.TrainList) do
		if not train.valid then
			table.remove(global.FuelTrainStop.TrainList,index)
			goto continue
		end
		if train.manual_mode then goto continue end
		local locs = train.locomotives
		for _,loc in pairs(locs.front_movers) do
			if lowFuel(loc) then
				addSchedule(train)
				goto continue
			end
		end
		for _,loc in pairs(locs.back_movers) do
			if lowFuel(loc) then
				addSchedule(train)
				goto continue
			end
		end
		::continue::
	end
end

function lowFuel(loc)
	local loc_inv = loc.get_fuel_inventory()
	if not loc_inv then return false end
	local contents = loc_inv.get_contents()
	local min_fuel = settings.global['min-fuel-amount'].value * loc.prototype.max_energy_usage * 800
	min_fuel = min_fuel / loc.prototype.burner_prototype.effectivity	
	if getEnergy(contents) < min_fuel then
		return true
	else
		return false
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

function addSchedule(train)
	local schedule = train.schedule or {}
	if not train.schedule then
		schedule.records = {}
	end
	for _,record in pairs(schedule.records) do
		if record.station == global.FuelTrainStop.BackerName then return end
	end
	local record = {station = global.FuelTrainStop.BackerName, wait_conditions = {}}
	record.wait_conditions[#record.wait_conditions+1] = {type = "inactivity", compare_type = "and", ticks = 120 }
	local current = schedule.current or 0
	table.insert(schedule.records,current+1,record)
	train.schedule = schedule
end

function removeFuelSchedule(event)
	if not (event.tick % 300 == 15 and #global.FuelTrainStop.FinishTrain > 0) then return end
	for index,train in pairs(global.FuelTrainStop.FinishTrain) do
		if not (train.station and train.station.backer_name == global.FuelTrainStop.BackerName) then 
			local schedule = train.schedule
			for i,record in pairs(schedule.records) do
				if record.station == global.FuelTrainStop.BackerName then
					table.remove(schedule.records,i)
					if i > #schedule.records then
						schedule.current = 1
					else
						schedule.current = i
					end					
					break
				end
			end
			train.schedule = schedule
			table.remove(global.FuelTrainStop.FinishTrain,index)
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
	local locs = train.locomotives
	for _,loc in pairs(locs.front_movers) do
		if Contains(TrainIgnoreList,loc.name) then goto continue end
	end
	for _,loc in pairs(locs.back_movers) do
		if Contains(TrainIgnoreList,loc.name) then goto continue end
	end
	if Contains(global.FuelTrainStop.TrainList,train) then goto continue end
	table.insert(global.FuelTrainStop.TrainList,train)
	::continue::
end

function ONARRIVE(event)
	local train = event.train
	if train.state == defines.train_state.wait_station then
		if train.station.backer_name == global.FuelTrainStop.BackerName then
			table.insert(global.FuelTrainStop.FinishTrain,train)
		end
	end
end

script.on_configuration_changed(ONCONFIG)
script.on_init(ONLOAD)
script.on_event(defines.events.on_tick,ONTICK)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity},ONBUILT)
script.on_event({defines.events.on_pre_player_mined_item,defines.events.on_robot_pre_mined,defines.events.on_entity_died},ONREMOVE)
script.on_event(defines.events.on_entity_renamed,ONRENAMED)
script.on_event(defines.events.on_train_created,ONNEWTRAIN)
script.on_event(defines.events.on_train_changed_state,ONARRIVE)