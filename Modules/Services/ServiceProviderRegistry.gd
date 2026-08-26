extends RefCounted

class_name ServiceProviderRegistry

const RECIPE_SHOWER: ServiceRecipe = preload("res://Modules/ServiceRecipes/shower.tres")
const RECIPE_BASIC_BED: ServiceRecipe = preload("res://Modules/ServiceRecipes/basic_bed.tres")
const RECIPE_BASIC_FOOD: ServiceRecipe = preload("res://Modules/ServiceRecipes/basic_food.tres")
const RECIPE_FAST_BASIC_FOOD: ServiceRecipe = preload("res://Modules/ServiceRecipes/fast_basic_food.tres")
const RECIPE_FAST_WATER: ServiceRecipe = preload("res://Modules/ServiceRecipes/fast_water.tres")
const RECIPE_BASIC_WATER: ServiceRecipe = preload("res://Modules/ServiceRecipes/basic_water.tres")
const RECIPE_BASIC_SOCIAL: ServiceRecipe = preload("res://Modules/ServiceRecipes/basic_social.tres")

const MODULE_SERVICES: Dictionary = {
	"cabin": [RECIPE_SHOWER, RECIPE_BASIC_BED],
	"kitchen": [RECIPE_FAST_BASIC_FOOD, RECIPE_FAST_WATER],
	"farm": [RECIPE_BASIC_FOOD],
	"lounge": [RECIPE_BASIC_SOCIAL],
	"clean_water": [RECIPE_BASIC_WATER]
}


static func get_recipes_for_module(module_type: String) -> Array[ServiceRecipe]:
	var recipes: Array[ServiceRecipe] = []
	if not MODULE_SERVICES.has(module_type):
		return recipes
	for recipe in MODULE_SERVICES[module_type]:
		recipes.append(recipe)
	return recipes
