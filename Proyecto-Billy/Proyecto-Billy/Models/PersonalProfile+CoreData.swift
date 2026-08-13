import CoreData

@objc(PersonalProfile)
final class PersonalProfile: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var firstName: String?
    @NSManaged var lastName: String?
    @NSManaged var documentNumber: String?
    @NSManaged var phone: String?
    @NSManaged var email: String?
    @NSManaged var birthDate: Date?
    @NSManaged var address: String?
    @NSManaged var emergencyContact: String?
    @NSManaged var notes: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var countryCode: String?
    @NSManaged var countryName: String?
}

extension PersonalProfile {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PersonalProfile> {
        NSFetchRequest<PersonalProfile>(entityName: "PersonalProfile")
    }

    var fullName: String {
        [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var snapshot: ProfileSnapshot {
        ProfileSnapshot(
            firstName: firstName,
            lastName: lastName,
            documentNumber: documentNumber,
            phone: phone,
            email: email,
            address: address,
            emergencyContact: emergencyContact,
            updatedAt: updatedAt
        )
    }

    var shareText: String {
        let values: [(String, String?)] = [
            ("Nombre", fullName),
            ("Documento", documentNumber),
            ("Teléfono", phone),
            ("Correo", email),
            ("País", countryName),
            ("Dirección", address),
            ("Contacto de emergencia", emergencyContact),
            ("Notas", notes)
        ]
        return values.compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return "\(label): \(value)"
        }.joined(separator: "\n")
    }
}
