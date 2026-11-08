import Foundation

struct Recipe: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var summary: String
    var servings: Int
    var prepMinutes: Int
    var cookMinutes: Int
    var ingredients: [RecipeIngredient]
    var instructions: [String]
    var tips: [String]
    var createdAt: Date = Date()
}
struct RecipeIngredient: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var unit: String
    var category: String
    var packageAmount: Double
    var packageUnit: String
    var packageLabel: String
}
struct PantryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var quantity: Double
    var unit: String
}
struct ShoppingItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var neededAmount: Double
    var unit: String
    var packageCount: Int
    var packageAmount: Double
    var packageUnit: String
    var packageLabel: String
    var recipeTitle: String
    var manualPrice: Double?
    var isPurchased: Bool
    var totalPackageQuantity: Double { Double(packageCount) * packageAmount }
    var leftover: Double { max(0, totalPackageQuantity - neededAmount) }
}
struct WalmartProduct: Identifiable, Hashable {
    var id: String { url.absoluteString }
    var title: String
    var url: URL
    var verifiedPrice: Decimal?
    var retrievedAt: Date?
}
