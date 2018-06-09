data:extend(
{
	{
		type = "item",
		name = "fuel-train-stop",
		icon = "__base__/graphics/icons/train-stop.png",
		flags = {"goes-to-quickbar"},
		subgroup = "transport",
		order = "a[train-system]-c[train-stop]-a[fuel-train-stop]",
		place_result = "fuel-train-stop",
		stack_size = 10
	},
	
	{
		type = "recipe",
		name = "fuel-train-stop",
		enabled = false,
		ingredients =
		{
			{"electronic-circuit", 5},
			{"iron-plate", 10},
			{"steel-plate", 3}
		},
		result = "fuel-train-stop"
	},
})

local f_stop = table.deepcopy(data.raw['train-stop']['train-stop'])
f_stop.name = "fuel-train-stop"
f_stop.minable = {mining_time = 1, result = "fuel-train-stop"},

data:extend{f_stop}

data.raw['technology']['automated-rail-transportation'].effects =
    {
      {
        type = "unlock-recipe",
        recipe = "train-stop"
      },
	  {
        type = "unlock-recipe",
        recipe = "fuel-train-stop"
      }	  
    }