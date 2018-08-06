require("lib")
require("lua.train_ignore_list")


function OnBuilt(event)
	local entity = event.created_entity
	if entity and entity.valid then
		if entity.name == "fuel-train-stop" then
			table.insert(global.TrainStop,entity)
			entity.backer_name = global.TrainStopName
		end
	end
end
	
	
function OnRemove(event)
	local entity = event.entity
	if entity and entity.valid then
		if entity.name == "fuel-train-stop" then
			for i,stop in pairs(global.TrainStop) do
				if stop == entity then
					table.remove(global.TrainStop,index)
					break
				end
			end
		end
	end
end


function OnEntityRenamed(event)
	if not event.by_script and event.entity.name == "fuel-train-stop" then
		global.TrainStopName = event.entity.backer_name
		for _,stop in pairs(global.TrainStop) do
			stop.backer_name = global.TrainStopName
		end
	end
end


function OnTrainCreated(event)
	local train = event.train
	local old_train_id_1 = event.old_train_id_1
	local old_train_id_2 = event.old_train_id_2

	for _,carriage in pairs(train.carriages) do
		if Contains(TrainIgnoreList,carriage.name) then
			if old_train_id_1 then		
				global.TrainList[old_train_id_1] = nil
			end
			if old_train_id_2 then
				global.TrainList[old_train_id_2] = nil
			end
			goto continue 
		end
	end
	
	global.TrainList[train.id] = train
	
	if old_train_id_1 then
		global.TrainList[old_train_id_1] = nil
		
		if global.FinishTrain[old_train_id_1] then
			global.FinishTrain[old_train_id_1] = nil
			global.FinishTrain[train.id] = train
		end	
	end
	if old_train_id_2 then
		global.TrainList[old_train_id_2] = nil
		
		if global.FinishTrain[old_train_id_2] then
			global.FinishTrain[old_train_id_2] = nil
			global.FinishTrain[train.id] = train
		end	
	end
	::continue::
end


function OnTrainChangedState(event)
	local train = event.train
	if train.state == defines.train_state.wait_station then
		if train.station.backer_name == global.TrainStopName then
			global.FinishTrain[train.id] = train
		end
	end
end


local function _GetEnergy(fuel_list)
	local e = 0
	for name,amount in pairs(fuel_list) do
		e = e + global.EnergyList[name] * amount
	end
	return e
end


local function _LowFuel(locomotive)
	local inventory = locomotive.get_fuel_inventory()
	if not inventory then return false end
	local contents = inventory.get_contents()
	local min_fuel = settings.global['min-fuel-amount'].value * locomotive.prototype.max_energy_usage * 800
	min_fuel = min_fuel / locomotive.prototype.burner_prototype.effectivity	
	if _GetEnergy(contents) < min_fuel then
		return true
	else
		return false
	end
end


local function _AddSchedule(train)
	local schedule = train.schedule or {}
	if not train.schedule then
		schedule.records = {}
	end
	for _,record in pairs(schedule.records) do
		if record.station == global.TrainStopName then return end
	end
	local record = {station = global.TrainStopName, wait_conditions = {}}
	record.wait_conditions[#record.wait_conditions+1] = {type = "inactivity", compare_type = "and", ticks = 120 }
	local current = schedule.current or 0
	table.insert(schedule.records,current+1,record)
	train.schedule = schedule
end


function OnTick1200()
	if Count(global.TrainStop) > 0 then 
		for i,train in pairs(global.TrainList) do
			if not train.valid then
				global.TrainList[i] = nil
				goto continue
			end
			
			if train.manual_mode then goto continue end
	
			for _,carriage in pairs(train.carriages) do
				if carriage.type == "locomotive" then
					if _LowFuel(carriage) then
						_AddSchedule(train)
						goto continue
					end
				end
			end
			::continue::
		end	
	end
end	


function OnTick300()
	if Count(global.FinishTrain) > 0 then
		for i,train in pairs(global.FinishTrain) do
			if not train.valid then
				global.FinishTrain[i] = nil
			else
				if not (train.station and train.station.backer_name == global.TrainStopName) then 
					local schedule = train.schedule
					for i,record in pairs(schedule.records) do
						if record.station == global.TrainStopName then
							table.remove(schedule.records,i)
							if i > Count(schedule.records) then
								schedule.current = 1
							else
								schedule.current = i
							end					
							break
						end
					end
					train.schedule = schedule
					global.FinishTrain[i] = nil
				end
			end
		end
	end
end