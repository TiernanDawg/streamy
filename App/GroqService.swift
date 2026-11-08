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

    // GPT-OSS 20B supports Groq strict structured outputs. This prevents
    // malformed or schema-invalid JSON from failing before the app can parse it.
    private static let recipeResponseFormat: [String: Any] = [
        "type": "json_schema",
        "json_schema": [
            "name": "frugalfork_recipe",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "summary": ["type": "string"],
                    "servings": ["type": "integer"],
                    "prepMinutes": ["type": "integer"],
                    "cookMinutes": ["type": "integer"],
                    "ingredients": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "amount": ["type": "number"],
                                "unit": ["type": "string"],
                                "category": ["type": "string"],
                                "packageAmount": ["type": "number"],
                                "packageUnit": ["type": "string"],
                                "packageLabel": ["type": "string"]
                            ],
                            "required": ["name", "amount", "unit", "category", "packageAmount", "packageUnit", "packageLabel"],
                            "additionalProperties": false
                        ]
                    ],
                    "instructions": ["type": "array", "items": ["type": "string"]],
                    "tips": ["type": "array", "items": ["type": "string"]]
                ],
                "required": ["title", "summary", "servings", "prepMinutes", "cookMinutes", "ingredients", "instructions", "tips"],
                "additionalProperties": false
            ]
        ]
    ]

    static func testAPIKey() async throws {
        guard let apiKey = KeychainStore.load(),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroqError.missingKey
        }

        // Test an actual completion, not merely whether the key can list models.
        let body: [String: Any] = [
            "model": recipeModel,
            "messages": [
                ["role": "system", "content": "Return a valid JSON object with one short test string."],
                ["role": "user", "content": "Reply with JSON containing the key result and value \"connection successful\"."]
            ],
            "response_format": ["type": "json_object"],
            "max_tokens": 80
        ]
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
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
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = result?["choices"] as? [[String: Any]]
        guard let message = choices?.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw GroqError.invalidResponse
        }
    }

    static func generateRecipe(idea: String, servings: Int, pantry: [PantryItem]) async throws -> Recipe {
        guard let apiKey = KeychainStore.load(), !apiKey.isEmpty else { throw GroqError.missingKey }
        let pantryDescription = pantry.isEmpty
            ? "The user has not entered any pantry items."
            : pantry.map { "\($0.name): \($0.quantity) \($0.unit)" }.joined(separator: "\n")

        let systemPrompt = """
        You are a practical home cook and grocery-cost optimizer. Create a complete, realistic recipe.
        The response is constrained to a JSON schema. Fill every required field with the correct type.
        Rules:
        - Ingredient quantities must be numeric and sufficient to make the complete meal.
        - Use common US kitchen units (oz, lb, cup, tbsp, tsp, each, clove).
        - Avoid specialty ingredients and expensive optional extras unless essential.
        - Prefer common ingredients and pantry staples where appropriate.
        - packageAmount/packageUnit/packageLabel are shopping guidance only, not verified Walmart listings or prices. Use a compatible unit when possible.
        - Do not include prices, nutrition claims, or ingredients unused in the instructions.
        - Include safe, sequential cooking instructions and realistic prep/cook times.
        - Return the requested serving count exactly.
        - Include every ingredient needed by the instructions.
        - Use an empty tips array if there are no useful tips.
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
            "response_format": recipeResponseFormat
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
        let draft: RecipeDraft
        do {
            draft = try JSONDecoder().decode(RecipeDraft.self, from: Data(cleaned.utf8))
        } catch {
            throw GroqError.invalidRecipeData
        }
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
    case missingKey, invalidResponse, invalidRecipeData, incompleteRecipe
    case connection(String)
    case http(status: Int, data: Data)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No Groq API key is saved. Add one in Settings."
        case .invalidResponse:
            return "Groq returned an unreadable response. Please try again."
        case .invalidRecipeData:
            return "Groq responded, but the recipe data could not be read. Please try again."
        case .incompleteRecipe:
            return "The generated recipe was missing ingredients or instructions. Try a more specific meal idea."
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
