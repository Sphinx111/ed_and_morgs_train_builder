extends RefCounted

class_name ModuleProducerRegistry

const RECIPE_CLEAN_WATER: ProductionRecipe = preload("res://Modules/Recipes/clean_water.tres")
const RECIPE_FOOD1: ProductionRecipe = preload("res://Modules/Recipes/food1.tres")
const RECIPE_FOOD2: ProductionRecipe = preload("res://Modules/Recipes/food2.tres")
const RECIPE_SCRAP_COLLECTOR: ProductionRecipe = preload("res://Modules/Recipes/scrap_collector.tres")
const RECIPE_SCRAP_TO_MECH: ProductionRecipe = preload("res://Modules/Recipes/scrap_to_mech.tres")
const RECIPE_PASSENGER_COLLECTOR: ProductionRecipe = preload("res://Modules/Recipes/passenger_collector.tres")
const RECIPE_WATER_COLLECTOR: ProductionRecipe = preload("res://Modules/Recipes/water_collector.tres")
const RECIPE_FUEL: ProductionRecipe = preload("res://Modules/Recipes/fuel.tres")

const MODULE_PRODUCERS: Dictionary = {
	"clean_water": [RECIPE_CLEAN_WATER],
	"farm": [RECIPE_FOOD1, RECIPE_FOOD2],
	"scrap_arm": [RECIPE_SCRAP_COLLECTOR],
	"mech_parts": [RECIPE_SCRAP_TO_MECH],
	"passenger_door": [RECIPE_PASSENGER_COLLECTOR],
	"water_collector": [RECIPE_WATER_COLLECTOR],
	"fuel_refinery": [RECIPE_FUEL],
}


static func get_recipes_for_module(module_type: String) -> Array[ProductionRecipe]:
	var recipes: Array[ProductionRecipe] = []
	if not MODULE_PRODUCERS.has(module_type):
		return recipes
	for recipe in MODULE_PRODUCERS[module_type]:
		recipes.append(recipe)
	return recipes
