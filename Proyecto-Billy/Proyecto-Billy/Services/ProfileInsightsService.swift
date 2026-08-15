import Foundation

enum ProfileStatus: String, CaseIterable, Sendable {
    case complete
    case missingContact
    case missingAddress
    case missingEmergency
}

struct ProfileSnapshot: Sendable {
    let firstName: String?
    let lastName: String?
    let documentNumber: String?
    let phone: String?
    let email: String?
    let address: String?
    let emergencyContact: String?
    let updatedAt: Date?
}

struct ProfileInsights: Sendable {
    let total: Int
    let complete: Int
    let recentlyUpdated: Int
    let withEmergencyContact: Int
    let statusCounts: [ProfileStatus: Int]
}

actor ProfileInsightsService {
    static let shared = ProfileInsightsService()

    func analyze(_ profiles: [ProfileSnapshot], now: Date = Date()) throws -> ProfileInsights {
        let recentLimit = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast
        var completeCount = 0
        var recentCount = 0
        var emergencyCount = 0
        var statusCounts: [ProfileStatus: Int] = [:]

        for (index, profile) in profiles.enumerated() {
            if index.isMultiple(of: 25) {
                try Task.checkCancellation()
            }

            let status = status(for: profile)
            statusCounts[status, default: 0] += 1
            if status == .complete { completeCount += 1 }
            if (profile.updatedAt ?? .distantPast) >= recentLimit { recentCount += 1 }
            if !isBlank(profile.emergencyContact) { emergencyCount += 1 }
        }

        return ProfileInsights(
            total: profiles.count,
            complete: completeCount,
            recentlyUpdated: recentCount,
            withEmergencyContact: emergencyCount,
            statusCounts: statusCounts
        )
    }

    private func status(for profile: ProfileSnapshot) -> ProfileStatus {
        if isBlank(profile.phone) && isBlank(profile.email) { return .missingContact }
        if isBlank(profile.address) { return .missingAddress }
        if isBlank(profile.emergencyContact) { return .missingEmergency }
        return isComplete(profile) ? .complete : .missingContact
    }

    private func isComplete(_ profile: ProfileSnapshot) -> Bool {
        !isBlank(profile.firstName) && !isBlank(profile.lastName) &&
            !isBlank(profile.documentNumber) && !isBlank(profile.phone) &&
            !isBlank(profile.email) && !isBlank(profile.address) &&
            !isBlank(profile.emergencyContact)
    }

    private func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}
