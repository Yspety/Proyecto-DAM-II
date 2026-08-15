import Foundation

nonisolated struct Country: Decodable, Sendable {
    nonisolated struct Name: Decodable, Sendable {
        let common: String
        let official: String
    }

    private nonisolated struct Region: Decodable, Sendable { let value: String }

    let name: Name
    let cca2: String
    let capital: [String]?
    let region: String
    let flag: String

    private enum CodingKeys: String, CodingKey {
        case iso2Code, name, region, capitalCity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let commonName = try container.decode(String.self, forKey: .name)
        let regionValue = try container.decode(Region.self, forKey: .region).value
        let capitalCity = try container.decode(String.self, forKey: .capitalCity)
        let code = try container.decode(String.self, forKey: .iso2Code)
        name = Name(common: commonName, official: commonName)
        cca2 = code
        capital = capitalCity.isEmpty ? nil : [capitalCity]
        region = regionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        flag = Self.flagEmoji(for: code)
    }

    private static func flagEmoji(for code: String) -> String {
        guard code.count == 2 else { return "🌐" }
        return code.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127_397 + $0.value).map(String.init)
        }.joined()
    }

    var displayName: String { "\(flag) \(name.common)" }
}

private nonisolated struct WorldBankCountriesResponse: Decodable, Sendable {
    let countries: [Country]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        _ = try container.decode(WorldBankPage.self)
        countries = try container.decode([Country].self)
    }
}

private nonisolated struct WorldBankPage: Decodable, Sendable {
    let page: Int
}

nonisolated enum APIClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case emptyResult
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "No se pudo construir la dirección del servicio."
        case .invalidResponse: "El servicio devolvió una respuesta no válida."
        case .httpStatus(let status): "El servicio respondió con el código HTTP \(status)."
        case .emptyResult: "No se encontraron países con ese nombre."
        case .decoding: "No se pudo interpretar la información recibida."
        }
    }
}

actor CountryAPIClient {
    static let shared = CountryAPIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private var cachedCountries: [Country]?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchCountries(named query: String) async throws -> [Country] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.worldbank.org/v2/country")
        components?.queryItems = [URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "per_page", value: "400")]
        guard let url = components?.url else { throw APIClientError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let allCountries: [Country]
        if let cachedCountries {
            allCountries = cachedCountries
        } else {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { throw APIClientError.httpStatus(http.statusCode) }
            do {
                allCountries = try decoder.decode(WorldBankCountriesResponse.self, from: data).countries
                    .filter { $0.region != "Aggregates" && !$0.cca2.isEmpty }
                cachedCountries = allCountries
            } catch {
                throw APIClientError.decoding(error)
            }
        }
        let comparableQuery = searchable(normalized)
        let matches = allCountries.filter {
            searchable($0.name.common).contains(comparableQuery) ||
                searchable($0.name.official).contains(comparableQuery) ||
                searchable($0.cca2).contains(comparableQuery)
        }.sorted { $0.name.common.localizedCaseInsensitiveCompare($1.name.common) == .orderedAscending }
        guard !matches.isEmpty else { throw APIClientError.emptyResult }
        return matches
    }

    private func searchable(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_PE"))
    }
}
