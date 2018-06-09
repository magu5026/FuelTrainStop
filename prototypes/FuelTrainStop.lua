local fts_item = table.deepcopy(data.raw['item']['train-stop'])
fts_item.name = "fuel-train-stop"
fts_item.order = "a[train-system]-c[train-stop]-a[fuel-train-stop]"
fts_item.place_result = "fuel-train-stop"

local fts_recipe = table.deepcopy(data.raw['recipe']['train-stop'])
fts_recipe.name = "fuel-train-stop"
fts_recipe.result = "fuel-train-stop"

local fts_entity = table.deepcopy(data.raw['train-stop']['train-stop'])
fts_entity.name = "fuel-train-stop"
fts_entity.minable.result = "fuel-train-stop"

data:extend({fts_item,fts_recipe,fts_entity})

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