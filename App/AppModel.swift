import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var recipes: [Recipe] = [] { didSet { save() } }
    var pantry: [PantryItem] = [] { didSet { save() } }
    var shoppingItems: [ShoppingItem] = [] { didSet { save() } }
    var zipCode: String = "18301" {
        didSet { UserDefaults.standard.set(zipCode, forKey: "savorcart.zip") }
    }
    var isGenerating = false
    var generationError: String?

    private let recipesKey = "savorcart.recipes"
    private let pantryKey = "savorcart.pantry"
    private let shoppingKey = "savorcart.shopping"

    init() {
        let defaults = UserDefaults.standard
        zipCode = defaults.string(forKey: "savorcart.zip") ?? "18301"
        recipes = Self.decode([Recipe].self, key: recipesKey, fallback: [])
        pantry = Self.decode([PantryItem].self, key: pantryKey, fallback: [])
        shoppingItems = Self.decode([ShoppingItem].self, key: shoppingKey, fallback: [])
    }

    var configuredGroqKey: Bool {
        guard let key = KeychainStore.load() else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func generate(idea: String, servings: Int) async -> Recipe? {
        generationError = nil
        isGenerating = true
        defer { isGenerating = false }
        do {
            let recipe = try await GroqService.generateRecipe(idea: idea, servings: servings, pantry: pantry)
            recipes.insert(recipe, at: 0)
            return recipe
        } catch {
            generationError = error.localizedDescription
            return nil
        }
    }

    func addRecipeToShoppingList(_ recipe: Recipe) {
        for ingredient in recipe.ingredients {
            let normalized = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let available = pantry.filter {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized &&
                $0.unit.lowercased() == ingredient.unit.lowercased()
            }.reduce(0.0) { $0 + $1.quantity }
            let needed = max(0, ingredient.amount - available)
            guard needed > 0 else { continue }
            let packAmount = ingredient.packageAmount > 0 &&
                ingredient.packageUnit.lowercased() == ingredient.unit.lowercased()
                ? ingredient.packageAmount : needed
            let count = max(1, Int(ceil(needed / max(packAmount, 0.001))))
            if let index = shoppingItems.firstIndex(where: {
                $0.name.lowercased() == normalized && $0.unit.lowercased() == ingredient.unit.lowercased()
            }) {
                shoppingItems[index].neededAmount += needed
                shoppingItems[index].packageCount = max(1, Int(ceil(shoppingItems[index].neededAmount / max(shoppingItems[index].packageAmount, 0.001))))
            } else {
                shoppingItems.append(ShoppingItem(name: ingredient.name, neededAmount: needed, unit: ingredient.unit,
                    packageCount: count, packageAmount: packAmount, packageUnit: ingredient.unit,
                    packageLabel: ingredient.packageLabel.isEmpty ? "Choose a package size at Walmart" : ingredient.packageLabel,
                    recipeTitle: recipe.title, manualPrice: nil, isPurchased: false))
            }
        }
    }

    func addPantryItem(name: String, quantity: Double, unit: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, quantity > 0 else { return }
        pantry.append(PantryItem(name: name.trimmingCharacters(in: .whitespacesAndNewlines), quantity: quantity, unit: unit))
    }
    func removePantryItem(_ item: PantryItem) { pantry.removeAll { $0.id == item.id } }
    func togglePurchased(_ item: ShoppingItem) {
        guard let index = shoppingItems.firstIndex(where: { $0.id == item.id }) else { return }
        shoppingItems[index].isPurchased.toggle()
    }
    func updatePrice(_ item: ShoppingItem, value: String) {
        guard let index = shoppingItems.firstIndex(where: { $0.id == item.id }) else { return }
        let cleaned = value.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        shoppingItems[index].manualPrice = Decimal(string: cleaned).map { NSDecimalNumber(decimal: $0).doubleValue }
    }
    func removeShoppingItem(_ item: ShoppingItem) { shoppingItems.removeAll { $0.id == item.id } }
    func clearShoppingList() { shoppingItems.removeAll() }
    func deleteRecipe(_ recipe: Recipe) { recipes.removeAll { $0.id == recipe.id } }
    func resetLocalData() {
        recipes.removeAll()
        pantry.removeAll()
        shoppingItems.removeAll()
    }

    private func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(recipes) { defaults.set(data, forKey: recipesKey) }
        if let data = try? JSONEncoder().encode(pantry) { defaults.set(data, forKey: pantryKey) }
        if let data = try? JSONEncoder().encode(shoppingItems) { defaults.set(data, forKey: shoppingKey) }
    }
    private static func decode<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(type, from: data) else { return fallback }
        return value
    }
}
