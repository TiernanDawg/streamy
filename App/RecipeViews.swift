import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var idea = ""
    @State private var servings = 4
    @State private var selectedRecipe: Recipe?
    private let suggestions = ["Cheap chicken Alfredo", "Ground beef tacos", "One-pot sausage pasta"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Cook for less.").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Tell us what sounds good. We'll build the recipe and the smallest practical shopping list.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 14)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("What do you want to make?", text: $idea, axis: .vertical)
                            .font(.system(size: 17)).lineLimit(1...3).submitLabel(.go)
                            .onSubmit { Task { await createRecipe() } }
                    }
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.08)))
                    HStack {
                        Label("Servings", systemImage: "person.2").foregroundStyle(.secondary)
                        Spacer()
                        Button { servings = max(1, servings - 1) } label: { Image(systemName: "minus").frame(width: 34, height: 34) }.buttonStyle(.bordered)
                        Text("\(servings)").font(.system(.headline, design: .rounded).monospacedDigit()).frame(minWidth: 24)
                        Button { servings = min(12, servings + 1) } label: { Image(systemName: "plus").frame(width: 34, height: 34) }.buttonStyle(.bordered)
                    }
                    Button { Task { await createRecipe() } } label: {
                        HStack {
                            if model.isGenerating { ProgressView().tint(.white) } else { Image(systemName: "sparkles") }
                            Text(model.isGenerating ? "Building your recipe…" : "Generate recipe").fontWeight(.semibold)
                        }.frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.17, green: 0.56, blue: 0.34))
                    .disabled(idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isGenerating)
                }
                if !model.configuredGroqKey {
                    Label("Add your Groq API key in Settings to start.", systemImage: "key")
                        .font(.footnote).foregroundStyle(.secondary).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                if let error = model.generationError {
                    ContentUnavailableView {
                        Label("Couldn't generate recipe", systemImage: "exclamationmark.triangle")
                    } description: { Text(error) } actions: {
                        Button("Try again") { Task { await createRecipe() } }.buttonStyle(.borderedProminent)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Try an idea").font(.headline)
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button { idea = suggestion } label: {
                            HStack {
                                Text(suggestion)
                                Spacer()
                                Image(systemName: "arrow.up.left").foregroundStyle(.secondary)
                            }.padding(13).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13))
                        }.buttonStyle(.plain).foregroundStyle(.primary)
                    }
                }
                if !model.recipes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recently created").font(.headline)
                            Spacer()
                            Text("\(model.recipes.count) saved").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(model.recipes.prefix(3)) { recipe in
                            Button { selectedRecipe = recipe } label: { RecipeRow(recipe: recipe) }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }
        .navigationTitle("SavorCart").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRecipe) { recipe in NavigationStack { RecipeDetailView(recipe: recipe) } }
    }
    private func createRecipe() async {
        if let recipe = await model.generate(idea: idea, servings: servings) { selectedRecipe = recipe }
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.13))
                Image(systemName: "fork.knife").font(.title2).foregroundStyle(.green)
            }.frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title).font(.headline).foregroundStyle(.primary)
                Text("\(recipe.servings) servings · \(recipe.prepMinutes + recipe.cookMinutes) min")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 17))
    }
}

struct SavedRecipesView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedRecipe: Recipe?
    var body: some View {
        Group {
            if model.recipes.isEmpty {
                ContentUnavailableView("No saved recipes", systemImage: "book.closed", description: Text("Recipes you generate will appear here."))
            } else {
                List {
                    ForEach(model.recipes) { recipe in
                        Button { selectedRecipe = recipe } label: { RecipeRow(recipe: recipe) }
                            .buttonStyle(.plain).listRowSeparator(.hidden)
                            .swipeActions {
                                Button(role: .destructive) { model.deleteRecipe(recipe) } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }.listStyle(.plain)
            }
        }
        .navigationTitle("Saved recipes")
        .sheet(item: $selectedRecipe) { recipe in NavigationStack { RecipeDetailView(recipe: recipe) } }
    }
}

struct RecipeDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var cookingMode = false
    @State private var added = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title).font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(recipe.summary).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Label("\(recipe.servings) servings", systemImage: "person.2")
                        Label("\(recipe.prepMinutes) min prep", systemImage: "clock")
                        Label("\(recipe.cookMinutes) min cook", systemImage: "flame")
                    }.font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    model.addRecipeToShoppingList(recipe)
                    added = true
                } label: {
                    Label(added ? "Shopping list updated" : "Add missing ingredients to list",
                          systemImage: added ? "checkmark.circle.fill" : "cart.badge.plus")
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                }.buttonStyle(.borderedProminent).tint(.green)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients").font(.title2.bold())
                    ForEach(recipe.ingredients) { ingredient in
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(ingredient.amount.formatted(.number.precision(.fractionLength(0...2)))) \(ingredient.unit)")
                                .fontWeight(.semibold).frame(minWidth: 94, alignment: .leading)
                            Text(ingredient.name)
                            Spacer(minLength: 0)
                        }.font(.body)
                        Divider()
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Instructions").font(.title2.bold())
                        Spacer()
                        Button(cookingMode ? "Exit cook mode" : "Cook mode") {
                            withAnimation(.snappy) { cookingMode.toggle() }
                        }.font(.subheadline.weight(.semibold))
                    }
                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(.green)
                                .frame(width: 26, height: 26).background(Color.green.opacity(0.12), in: Circle())
                            Text(step).font(cookingMode ? .title3 : .body).fixedSize(horizontal: false, vertical: true)
                        }.padding(.vertical, 5)
                    }
                }
                if !recipe.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cook's notes").font(.title3.bold())
                        ForEach(recipe.tips, id: \.self) { Text("• \($0)").foregroundStyle(.secondary) }
                    }
                }
            }.padding(20)
        }
        .navigationTitle("Recipe").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
}

struct PantryView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var quantity = "1"
    @State private var unit = "each"
    private let units = ["each", "oz", "lb", "cup", "tbsp", "tsp", "clove", "can", "jar"]

    var body: some View {
        List {
            Section("Add what you already have") {
                TextField("Ingredient (e.g. pasta)", text: $name)
                HStack {
                    TextField("Quantity", text: $quantity).keyboardType(.decimalPad).frame(width: 90)
                    Picker("Unit", selection: $unit) { ForEach(units, id: \.self) { Text($0).tag($0) } }
                    Spacer()
                    Button("Add") {
                        guard let amount = Double(quantity) else { return }
                        model.addPantryItem(name: name, quantity: amount, unit: unit)
                        name = ""; quantity = "1"
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(quantity) == nil)
                }
            }
            Section("Your inventory") {
                if model.pantry.isEmpty {
                    ContentUnavailableView("Pantry is empty", systemImage: "cabinet",
                        description: Text("Add ingredients you own. The recipe builder will subtract matching quantities."))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(model.pantry) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).fontWeight(.medium)
                                Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...2)))) \(item.unit)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.swipeActions {
                            Button(role: .destructive) { model.removePantryItem(item) } label: { Label("Remove", systemImage: "trash") }
                        }
                    }
                }
            }.footer {
                Text("Pantry deductions require matching ingredient names and units. Check quantities before shopping.")
            }
        }.navigationTitle("Pantry")
    }
}

struct ShoppingView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedItem: ShoppingItem?
    private var total: Double {
        model.shoppingItems.compactMap { item in item.manualPrice.map { $0 * Double(item.packageCount) } }.reduce(0, +)
    }
    var body: some View {
        Group {
            if model.shoppingItems.isEmpty {
                ContentUnavailableView("Your list is empty", systemImage: "cart",
                    description: Text("Generate a recipe and add its missing ingredients to build a Walmart list."))
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Confirmed item total").font(.caption).foregroundStyle(.secondary)
                            Text(total, format: .currency(code: "USD")).font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("Only manually confirmed prices are included. Tax, substitutions and unavailable prices are excluded.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                    ForEach(model.shoppingItems) { item in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(alignment: .top) {
                                Button { model.togglePurchased(item) } label: {
                                    Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                                        .font(.title3).foregroundStyle(item.isPurchased ? .green : .secondary)
                                }.buttonStyle(.plain)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name).font(.headline).strikethrough(item.isPurchased)
                                    Text("Need \(item.neededAmount.formatted(.number.precision(.fractionLength(0...2)))) \(item.unit) · Buy \(item.packageCount) × \(item.packageLabel)")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if item.leftover > 0.01 {
                                        Text("Approx. leftover: \(item.leftover.formatted(.number.precision(.fractionLength(0...2)))) \(item.unit)")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button { selectedItem = item } label: {
                                    Image(systemName: "magnifyingglass").frame(width: 36, height: 36)
                                        .background(.thinMaterial, in: Circle())
                                }.buttonStyle(.plain).accessibilityLabel("Find \(item.name) at Walmart")
                            }
                            HStack {
                                Text("Price per package").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                TextField("$0.00", text: Binding(
                                    get: { item.manualPrice.map { String(format: "%.2f", $0) } ?? "" },
                                    set: { model.updatePrice(item, value: $0) }
                                )).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .frame(width: 92).textFieldStyle(.roundedBorder)
                            }
                        }.padding(.vertical, 5)
                            .swipeActions {
                                Button(role: .destructive) { model.removeShoppingItem(item) } label: { Label("Remove", systemImage: "trash") }
                            }
                    }
                    Section {
                        Button("Clear shopping list", role: .destructive) { model.clearShoppingList() }
                    }
                }.listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Shopping list")
        .sheet(item: $selectedItem) { item in NavigationStack { WalmartSearchView(item: item) } }
    }
}

struct WalmartSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: ShoppingItem
    @State private var products: [WalmartProduct] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    private var searchURL: URL { WalmartService.searchURL(for: item.name, zipCode: model.zipCode) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name).font(.title2.bold())
                    Text("Walmart search · ZIP \(model.zipCode)").font(.caption).foregroundStyle(.secondary)
                    Link(destination: searchURL) {
                        Label("Open Walmart search", systemImage: "arrow.up.right.square").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                }.padding(.vertical, 8)
            }
            if isLoading {
                HStack { Spacer(); ProgressView("Checking accessible product data…"); Spacer() }
            } else if let errorMessage {
                ContentUnavailableView("Live listings unavailable", systemImage: "cart.badge.questionmark", description: Text(errorMessage))
            } else if products.isEmpty {
                ContentUnavailableView("No verifiable product data", systemImage: "magnifyingglass",
                    description: Text("Walmart did not expose product details in its public search page. Open the search above and confirm the package and price yourself."))
            } else {
                Section("Listings found") {
                    ForEach(products) { product in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(product.title).font(.headline)
                            if let price = product.verifiedPrice {
                                Text(NSDecimalNumber(decimal: price), formatter: Self.currencyFormatter).font(.title3.bold())
                                Text("Retrieved \(product.retrievedAt ?? Date(), style: .time) · Walmart page data")
                                    .font(.caption2).foregroundStyle(.secondary)
                            } else {
                                Text("Price not exposed by Walmart").font(.caption).foregroundStyle(.secondary)
                            }
                            Link("Open product listing", destination: product.url)
                        }.padding(.vertical, 5)
                    }
                }
            }
            Section {
                Text("Prices are shown as verified only when an actual price was retrieved from the Walmart page. Search pages can block automated access or omit local pricing; manually confirm the item, package size, ZIP and final cart price.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Walmart").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .task { await loadProducts() }
    }
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    private func loadProducts() async {
        do {
            products = try await WalmartService.searchProducts(query: item.name, zipCode: model.zipCode)
            if products.isEmpty {
                errorMessage = "No structured product listings were available. Use the Walmart search link and enter the confirmed price in your list."
            }
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
