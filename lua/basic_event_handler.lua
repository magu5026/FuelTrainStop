require("lib")
require("lua.train_ignore_list")


local function _Init()
	global.TrainStop = global.TrainStop or {}
	global.EnergyList = {}
	global.TrainStopName = global.TrainStopName or "Fuel Stop"


	global.FinishTrain = global.FinishTrain or {}
	global.TrainList = {}
end


local function _EnableTech()
	for _,force in pairs(game.forces) do
		local tech = force.technologies['automated-rail-transportation']
		if tech and tech.researched then 
			force.recipes['fuel-train-stop'].enabled = true
		end
	end
end


local function _GetEnergyList()
	for _,item in pairs(game.item_prototypes) do
		if item.fuel_category then
			global.EnergyList[item.name] = item.fuel_value
		end
	end
end


local function _GetTrainList()
	for _,surface in pairs(game.surfaces) do
		local trains = surface.get_trains()
		for _,train in pairs(trains) do
			for _,carriage in pairs(train.carriages) do
				if Contains(TrainIgnoreList,carriage.name) then goto continue end
			end
			
			global.TrainList[train.id] = train
			::continue::
		end
	end
end	


function OnInit()
	_Init()
	_EnableTech()
	_GetEnergyList()
	_GetTrainList()
end


function OnConfigurationChanged(data)
	_Init()
	_GetEnergyList()
	_GetTrainList()	

	local mod_name = "FuelTrainStop"
	if NeedMigration(data,mod_name) then
		local old_version = GetOldVersion(data,mod_name)
		if old_version < "00.16.02" then
			global.TrainStop = {}
	
			for _,surface in pairs(game.surfaces) do
				local train_stops = surface.find_entities_filtered{name="fuel-train-stop"}
				for _,stop in pairs(train_stops) do
					table.insert(global.TrainStop,stop)
				end
			end	
			
			if Count(global.TrainStop) > 0 then
				global.TrainStopName = global.TrainStop[1].backer_name or "Fuel Stop"
			end
			
			for _,train in pairs(global.TrainList) do
				local schedule = train.schedule
				if schedule then
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
				end
			end
		end
	end
end