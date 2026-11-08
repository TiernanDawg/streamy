import Foundation

enum WalmartService {
    static func searchURL(for query: String, zipCode: String) -> URL {
        var components = URLComponents(string: "https://www.walmart.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        if !zipCode.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "facet", value: "fulfillment_method_in_store"))
        }
        return components.url!
    }

    static func searchProducts(query: String, zipCode: String) async throws -> [WalmartProduct] {
        var request = URLRequest(url: searchURL(for: query, zipCode: zipCode))
        request.timeoutInterval = 18
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw WalmartSearchError.unavailable
        }
        return parseStructuredProducts(from: html)
    }

    private static func parseStructuredProducts(from html: String) -> [WalmartProduct] {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var products: [WalmartProduct] = []
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let json = String(html[range])
            guard let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else { continue }
            collectProducts(from: object, into: &products)
        }
        var seen = Set<String>()
        return products.filter { seen.insert($0.id).inserted }.prefix(12).map { $0 }
    }

    private static func collectProducts(from object: Any, into products: inout [WalmartProduct]) {
        if let array = object as? [Any] {
            array.forEach { collectProducts(from: $0, into: &products) }
            return
        }
        guard let dictionary = object as? [String: Any] else { return }
        let type = dictionary["@type"] as? String ?? ""
        if type.localizedCaseInsensitiveContains("Product"),
           let name = dictionary["name"] as? String,
           let rawURL = dictionary["url"] as? String,
           let url = URL(string: rawURL, relativeTo: URL(string: "https://www.walmart.com")),
           url.host?.contains("walmart.com") == true {
            let offers = dictionary["offers"] as? [String: Any]
            let rawPrice = offers?["price"] as? String ?? (offers?["price"] as? NSNumber)?.stringValue
            let price = rawPrice.flatMap { Decimal(string: $0) }
            products.append(WalmartProduct(title: name, url: url, verifiedPrice: price,
                retrievedAt: price == nil ? nil : Date()))
        }
        dictionary.values.forEach { collectProducts(from: $0, into: &products) }
    }
}
enum WalmartSearchError: LocalizedError {
    case unavailable
    var errorDescription: String? {
        "Walmart did not provide readable product data. You can still open its search page and confirm the product and price manually."
    }
}
