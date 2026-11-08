import Foundation

private struct RecipeDraft: Decodable {
    let title: String
    let summary: String
    let servings: Int
    let prepMinutes: Int
    let cookMinutes: Int
    let ingredients: [IngredientDraft]
    let instructions: [String]
    let tips: [String]
}
private struct IngredientDraft: Decodable {
    let name: String
    let amount: Double
    let unit: String
    let category: String
    let packageAmount: Double
    let packageUnit: String
    let packageLabel: String
}

private struct GroqModelsResponse: Decodable {
    struct Model: Decodable { let id: String }
    let data: [Model]
}

enum GroqService {
    private static let recipeModel = "openai/gpt-oss-20b"
    private static let baseURL = URL(string: "https://api.groq.com/openai/v1")!

    static func testAPIKey() async throws {
        guard let apiKey = KeychainStore.load(),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroqError.missingKey
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GroqError.connection(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw GroqError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw GroqError.http(status: http.statusCode, data: data)
        }
        let models = try JSONDecoder().decode(GroqModelsResponse.self, from: data)
        guard models.data.contains(where: { $0.id == recipeModel }) else {
            throw GroqError.modelUnavailable
        }
    }

    static func generateRecipe(idea: String, servings: Int, pantry: [PantryItem]) async throws -> Recipe {
        guard let apiKey = KeychainStore.load(), !apiKey.isEmpty else { throw GroqError.missingKey }
        let pantryDescription = pantry.isEmpty
            ? "The user has not entered any pantry items."
            : pantry.map { "\($0.name): \($0.quantity) \($0.unit)" }.joined(separator: "\n")

        let systemPrompt = """
        You are a practical home cook and grocery-cost optimizer. Create a complete, realistic recipe.
        Return ONLY one valid JSON object. Do not use Markdown or code fences.
        Use this exact shape:
        {
          "title": "string", "summary": "string", "servings": 4,
          "prepMinutes": 10, "cookMinutes": 20,
          "ingredients": [{"name":"ingredient","amount":1.5,"unit":"cup","category":"Produce","packageAmount":8,"packageUnit":"oz","packageLabel":"small practical package"}],
          "instructions": ["step one", "step two"], "tips": ["optional tip"]
        }
        Rules:
        - Ingredient quantities must be numeric and sufficient to make the complete meal.
        - Use common US kitchen units (oz, lb, cup, tbsp, tsp, each, clove).
        - Avoid specialty ingredients and expensive optional extras unless essential.
        - Prefer common ingredients and pantry staples where appropriate.
        - packageAmount/packageUnit/packageLabel are shopping guidance only, not verified Walmart listings or prices. Use a compatible unit when possible.
        - Do not include prices, nutrition claims, or ingredients unused in the instructions.
        - Include safe, sequential cooking instructions and realistic prep/cook times.
        - Return the requested serving count exactly.
        """

        let userPrompt = """
        Meal idea: \(idea)
        Target servings: \(servings)
        Ingredients already in the user's kitchen:
        \(pantryDescription)
        Make the complete meal with the fewest practical new purchases. Do not list pantry ingredients as purchases when inventory covers the needed amount. Keep it affordable without making it incomplete.
        """
        let body: [String: Any] = [
            "model": recipeModel,
            "temperature": 0.25,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"]
        ]
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GroqError.connection(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw GroqError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw GroqError.http(status: http.statusCode, data: data)
        }
        let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = envelope?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String else { throw GroqError.invalidResponse }
        let cleaned = content.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = try JSONDecoder().decode(RecipeDraft.self, from: Data(cleaned.utf8))
        guard !draft.title.isEmpty, !draft.ingredients.isEmpty, !draft.instructions.isEmpty else {
            throw GroqError.incompleteRecipe
        }
        let ingredients = draft.ingredients.map {
            RecipeIngredient(name: $0.name, amount: max(0, $0.amount), unit: $0.unit,
                category: $0.category, packageAmount: max(0, $0.packageAmount),
                packageUnit: $0.packageUnit, packageLabel: $0.packageLabel)
        }
        return Recipe(title: draft.title, summary: draft.summary, servings: max(1, draft.servings),
            prepMinutes: max(0, draft.prepMinutes), cookMinutes: max(0, draft.cookMinutes),
            ingredients: ingredients, instructions: draft.instructions, tips: draft.tips)
    }
}

enum GroqError: LocalizedError {
    case missingKey, invalidResponse, incompleteRecipe, modelUnavailable
    case connection(String)
    case http(status: Int, data: Data)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No Groq API key is saved. Add one in Settings."
        case .invalidResponse:
            return "Groq returned an unreadable response. Please try again."
        case .incompleteRecipe:
            return "The generated recipe was missing ingredients or instructions. Try a more specific meal idea."
        case .modelUnavailable:
            return "The key is valid, but Groq did not list the recipe model (openai/gpt-oss-20b) for this account."
        case .connection(let detail):
            return "Could not reach Groq. Check your internet connection and try again. Details: \(detail)"
        case .http(let status, let data):
            let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let errorObject = raw?["error"] as? [String: Any]
            let message = errorObject?["message"] as? String
            if status == 401 || status == 403 {
                return "Groq rejected this API key (HTTP \(status)). Check that it was copied correctly, is active, and belongs to your Groq account. Create or replace it at console.groq.com/keys."
            }
            return "Groq returned HTTP \(status): \(message ?? "Unexpected API error. Please try again.")"
        }
    }
}
