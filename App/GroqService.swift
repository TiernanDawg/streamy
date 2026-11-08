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

    enum CodingKeys: String, CodingKey {
        case title, summary, servings, prepMinutes, cookMinutes, ingredients, instructions, tips
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = values.string(.title)
        summary = values.string(.summary)
        servings = values.integer(.servings, default: 1)
        prepMinutes = values.integer(.prepMinutes, default: 0)
        cookMinutes = values.integer(.cookMinutes, default: 0)
        ingredients = (try? values.decode([IngredientDraft].self, forKey: .ingredients)) ?? []
        instructions = (try? values.decode([String].self, forKey: .instructions)) ?? []
        tips = (try? values.decode([String].self, forKey: .tips)) ?? []
    }
}

private struct IngredientDraft: Decodable {
    let name: String
    let amount: Double
    let unit: String
    let category: String
    let packageAmount: Double
    let packageUnit: String
    let packageLabel: String

    enum CodingKeys: String, CodingKey {
        case name, amount, unit, category, packageAmount, packageUnit, packageLabel
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = values.string(.name)
        amount = values.number(.amount, default: 0)
        unit = values.string(.unit, default: "each")
        category = values.string(.category, default: "Other")
        packageAmount = values.number(.packageAmount, default: 0)
        packageUnit = values.string(.packageUnit, default: unit)
        packageLabel = values.string(.packageLabel, default: "Confirm package size at Walmart")
    }
}

private extension KeyedDecodingContainer {
    func string(_ key: Key, default fallback: String = "") -> String {
        (try? decode(String.self, forKey: key)) ?? fallback
    }

    func number(_ key: Key, default fallback: Double) -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? decode(String.self, forKey: key), let parsed = Double(value) { return parsed }
        return fallback
    }

    func integer(_ key: Key, default fallback: Int) -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        if let value = try? decode(String.self, forKey: key), let parsed = Int(value) { return parsed }
        return fallback
    }
}

private struct GroqCompletion {
    let content: String
    let finishReason: String?
}

enum GroqService {
    private static let model = "openai/gpt-oss-20b"
    private static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    // Only required recipe data is in the schema. Optional cooking notes never
    // block a recipe when a model omits them.
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
                    "instructions": ["type": "array", "items": ["type": "string"]]
                ],
                "required": ["title", "summary", "servings", "prepMinutes", "cookMinutes", "ingredients", "instructions"],
                "additionalProperties": false
            ]
        ]
    ]

    static func testAPIKey(_ candidateKey: String? = nil) async throws {
        let suppliedKey = candidateKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let apiKey = (suppliedKey?.isEmpty == false ? suppliedKey : KeychainStore.load()),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroqError.missingKey
        }

        // Test the selected model's real inference endpoint, without JSON mode.
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Reply with the short phrase: FrugalFork connection successful."]
            ],
            "max_completion_tokens": 96,
            "reasoning_effort": "low",
            "reasoning_format": "hidden",
            "temperature": 0
        ]
        let completion = try await send(body: body, apiKey: apiKey, timeout: 25)
        guard !completion.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroqError.invalidResponse
        }
    }

    static func generateRecipe(idea: String, servings: Int, pantry: [PantryItem]) async throws -> Recipe {
        guard let apiKey = KeychainStore.load(),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroqError.missingKey
        }

        let pantryDescription = pantry.isEmpty
            ? "No pantry items have been entered."
            : pantry.map { "\($0.name): \($0.quantity) \($0.unit)" }.joined(separator: "\n")

        let systemPrompt = """
        You are FrugalFork, a practical home cook and grocery-cost optimizer.
        Create one complete, affordable, realistic recipe for the requested servings.
        Return one JSON object with these fields:
        title (string), summary (string), servings (integer), prepMinutes (integer),
        cookMinutes (integer), ingredients (array of objects), and instructions (array of strings).
        Every ingredient object must contain:
        name (string), amount (number), unit (string), category (string),
        packageAmount (number), packageUnit (string), and packageLabel (string).
        Rules:
        - Include every ingredient needed by the instructions, with realistic quantities.
        - Use familiar US units: oz, lb, cup, tbsp, tsp, each, clove, can.
        - Favor low-cost ingredients and avoid unnecessary specialty items.
        - Do not add ingredients that are not used in the instructions.
        - Package sizes are shopping guidance, not verified Walmart listings or prices.
        - Give safe, sequential cooking steps and realistic times.
        - The servings value must exactly equal the requested servings.
        - Do not include Markdown, code fences, comments, or text outside the JSON object.
        - Do not include a tips field.
        """

        let userPrompt = """
        Meal idea: \(idea)
        Requested servings: \(servings)
        Current pantry:
        \(pantryDescription)

        Make the complete meal using as few practical new purchases as possible.
        Subtract pantry ingredients only when the name and unit match exactly.
        Keep the meal affordable without omitting ingredients necessary for a complete recipe.
        """

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.2,
            "max_completion_tokens": 3000,
            "reasoning_effort": "low",
            "reasoning_format": "hidden",
            "response_format": recipeResponseFormat
        ]

        do {
            return try await requestRecipe(body: requestBody, apiKey: apiKey, servings: servings)
        } catch let error as GroqError where error.shouldRetryWithoutSchema {
            // If structured-output validation fails, retry once without server
            // schema validation. The app still parses and validates all fields.
            requestBody.removeValue(forKey: "response_format")
            requestBody["messages"] = [
                ["role": "system", "content": systemPrompt + "\nReturn valid JSON only. All listed fields must be present. Do not include tips."],
                ["role": "user", "content": userPrompt]
            ] as [[String: String]]
            return try await requestRecipe(body: requestBody, apiKey: apiKey, servings: servings)
        }
    }

    private static func requestRecipe(body: [String: Any], apiKey: String, servings: Int) async throws -> Recipe {
        let completion = try await send(body: body, apiKey: apiKey, timeout: 90)
        if completion.finishReason == "length" { throw GroqError.truncatedResponse }

        let draft = try decodeDraft(from: completion.content)
        let ingredients = draft.ingredients.compactMap { item -> RecipeIngredient? in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, item.amount > 0 else { return nil }
            return RecipeIngredient(
                name: name,
                amount: item.amount,
                unit: item.unit,
                category: item.category,
                packageAmount: max(0, item.packageAmount),
                packageUnit: item.packageUnit,
                packageLabel: item.packageLabel
            )
        }
        let instructions = draft.instructions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !ingredients.isEmpty,
              !instructions.isEmpty else {
            throw GroqError.incompleteRecipe
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return Recipe(
            title: title,
            summary: summary.isEmpty ? "A practical homemade \(title.lowercased()) recipe." : summary,
            servings: min(12, max(1, servings)),
            prepMinutes: max(0, draft.prepMinutes),
            cookMinutes: max(0, draft.cookMinutes),
            ingredients: ingredients,
            instructions: instructions,
            tips: draft.tips
        )
    }

    private static func send(body: [String: Any], apiKey: String, timeout: TimeInterval) async throws -> GroqCompletion {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GroqError.connection(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw GroqError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw GroqError.http(status: http.statusCode, data: data)
        }

        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = envelope["choices"] as? [[String: Any]],
              let choice = choices.first,
              let message = choice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.invalidResponse
        }
        return GroqCompletion(content: content, finishReason: choice["finish_reason"] as? String)
    }

    private static func decodeDraft(from content: String) throws -> RecipeDraft {
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let decoder = JSONDecoder()
        if let data = cleaned.data(using: .utf8),
           let draft = try? decoder.decode(RecipeDraft.self, from: data) {
            return draft
        }

        guard let object = extractJSONObject(from: cleaned),
              let data = object.data(using: .utf8),
              let draft = try? decoder.decode(RecipeDraft.self, from: data) else {
            throw GroqError.invalidRecipeData
        }
        return draft
    }

    // Recover a JSON object if the plain-text retry adds a preamble or code fence.
    // Braces inside quoted strings are ignored so recipe instructions remain intact.
    private static func extractJSONObject(from text: String) -> String? {
        var start: String.Index?
        var depth = 0
        var insideString = false
        var isEscaped = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if start == nil {
                if character == "{" {
                    start = index
                    depth = 1
                }
            } else if insideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    insideString = false
                }
            } else {
                if character == "\"" {
                    insideString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0, let start {
                        return String(text[start...index])
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
}

enum GroqError: LocalizedError {
    case missingKey
    case invalidResponse
    case invalidRecipeData
    case incompleteRecipe
    case truncatedResponse
    case connection(String)
    case http(status: Int, data: Data)

    var shouldRetryWithoutSchema: Bool {
        switch self {
        case .invalidRecipeData, .incompleteRecipe:
            return true
        case .http(let status, let data):
            guard status == 400 else { return false }
            let detail = String(data: data, encoding: .utf8)?.lowercased() ?? ""
            return detail.contains("schema") || detail.contains("json") || detail.contains("failed_generation")
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No Groq API key is saved. Add one in Settings."
        case .invalidResponse:
            return "Groq responded without a usable completion. Try again."
        case .invalidRecipeData:
            return "Groq responded, but the recipe data could not be read after an automatic retry. Try a more specific meal idea."
        case .incompleteRecipe:
            return "Groq returned an incomplete recipe after an automatic retry. Try a more specific meal idea."
        case .truncatedResponse:
            return "Groq stopped before finishing the recipe. Try again with a shorter meal description."
        case .connection(let detail):
            return "Could not reach Groq. Check your internet connection. Details: \(detail)"
        case .http(let status, let data):
            let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let errorObject = raw?["error"] as? [String: Any]
            let message = errorObject?["message"] as? String

            if status == 401 || status == 403 {
                return "Groq rejected this API key (HTTP \(status)). Check that it is active and copied correctly, or create a new key at console.groq.com/keys."
            }
            if status == 429 {
                return "Groq rate or usage limit reached (HTTP 429). Check your Groq limits and billing, then try again."
            }
            if status >= 500 {
                return "Groq is temporarily unavailable (HTTP \(status)). Try again shortly."
            }
            return "Groq returned HTTP \(status): \(message ?? "The request was rejected. Please try again.")"
        }
    }
}
