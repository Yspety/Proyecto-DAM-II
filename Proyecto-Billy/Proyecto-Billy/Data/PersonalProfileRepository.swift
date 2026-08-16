import CoreData
import UIKit

struct PersonalProfileInput {
    let firstName: String
    let lastName: String
    let documentNumber: String
    let phone: String?
    let email: String?
    let birthDate: Date?
    let address: String?
    let emergencyContact: String?
    let notes: String?
    let countryCode: String?
    let countryName: String?
}

enum PersonalProfileRepositoryError: LocalizedError {
    case duplicateDocumentNumber

    var errorDescription: String? {
        switch self {
        case .duplicateDocumentNumber:
            return "Ya existe un perfil registrado con este DNI."
        }
    }
}

@MainActor
final class PersonalProfileRepository {
    static let shared = PersonalProfileRepository()
    static let didChange = Notification.Name("PersonalProfileRepository.didChange")

    private var viewContext: NSManagedObjectContext {
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            preconditionFailure("AppDelegate no está disponible")
        }
        return delegate.persistentContainer.viewContext
    }

    private init() {}

    func makeFetchedResultsController() -> NSFetchedResultsController<PersonalProfile> {
        let request = PersonalProfile.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PersonalProfile.lastName), ascending: true),
            NSSortDescriptor(key: #keyPath(PersonalProfile.firstName), ascending: true)
        ]
        return NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    func fetchAll() throws -> [PersonalProfile] {
        let request = PersonalProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(PersonalProfile.updatedAt), ascending: false)]
        return try viewContext.fetch(request)
    }

    func isDocumentNumberAvailable(
        _ documentNumber: String,
        excluding profile: PersonalProfile? = nil
    ) throws -> Bool {
        let normalizedDocument = documentNumber.trimmed
        guard !normalizedDocument.isEmpty else { return false }

        let request = PersonalProfile.fetchRequest()
        request.fetchLimit = 2
        request.predicate = NSPredicate(format: "documentNumber == %@", normalizedDocument)
        let matches = try viewContext.fetch(request)
        return !matches.contains { candidate in
            guard let profile else { return true }
            return candidate.objectID != profile.objectID
        }
    }

    func merge(_ cloudProfiles: [CloudProfile]) throws {
        for cloud in cloudProfiles {
            let request = PersonalProfile.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", cloud.id as CVarArg)
            let profile = try viewContext.fetch(request).first ?? PersonalProfile(context: viewContext)
            if profile.id == nil { profile.id = cloud.id }
            if let localDate = profile.updatedAt, let cloudDate = cloud.updatedAt, localDate > cloudDate { continue }
            profile.firstName = cloud.firstName
            profile.lastName = cloud.lastName
            profile.documentNumber = cloud.documentNumber
            profile.phone = cloud.phone
            profile.email = cloud.email
            profile.birthDate = cloud.birthDate
            profile.address = cloud.address
            profile.emergencyContact = cloud.emergencyContact
            profile.notes = cloud.notes
            profile.countryCode = cloud.countryCode
            profile.countryName = cloud.countryName
            profile.createdAt = cloud.createdAt
            profile.updatedAt = cloud.updatedAt
        }
        try save()
    }

    @discardableResult
    func create(_ input: PersonalProfileInput) throws -> PersonalProfile {
        try ensureUniqueDocumentNumber(input.documentNumber)
        let profile = PersonalProfile(context: viewContext)
        profile.id = UUID()
        profile.createdAt = Date()
        apply(input, to: profile)
        try save()
        return profile
    }

    func update(_ profile: PersonalProfile, with input: PersonalProfileInput) throws {
        try ensureUniqueDocumentNumber(input.documentNumber, excluding: profile)
        apply(input, to: profile)
        try save()
    }

    func delete(_ profile: PersonalProfile) throws {
        viewContext.delete(profile)
        try save()
    }

    func deleteAll() throws {
        let profiles = try fetchAll()
        profiles.forEach { viewContext.delete($0) }
        try save()
    }

    private func ensureUniqueDocumentNumber(
        _ documentNumber: String,
        excluding profile: PersonalProfile? = nil
    ) throws {
        guard try isDocumentNumberAvailable(documentNumber, excluding: profile) else {
            throw PersonalProfileRepositoryError.duplicateDocumentNumber
        }
    }

    private func apply(_ input: PersonalProfileInput, to profile: PersonalProfile) {
        profile.firstName = input.firstName.trimmed
        profile.lastName = input.lastName.trimmed
        profile.documentNumber = input.documentNumber.trimmed
        profile.phone = input.phone?.nilIfBlank
        profile.email = input.email?.nilIfBlank
        profile.birthDate = input.birthDate
        profile.address = input.address?.nilIfBlank
        profile.emergencyContact = input.emergencyContact?.nilIfBlank
        profile.notes = input.notes?.nilIfBlank
        profile.countryCode = input.countryCode?.nilIfBlank
        profile.countryName = input.countryName?.nilIfBlank
        profile.updatedAt = Date()
    }

    private func save() throws {
        guard viewContext.hasChanges else { return }
        try viewContext.save()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
