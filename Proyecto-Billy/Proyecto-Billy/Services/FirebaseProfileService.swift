import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

struct CloudProfile: Sendable {
    let id: UUID
    let firstName: String?
    let lastName: String?
    let documentNumber: String?
    let phone: String?
    let email: String?
    let birthDate: Date?
    let address: String?
    let emergencyContact: String?
    let notes: String?
    let countryCode: String?
    let countryName: String?
    let createdAt: Date?
    let updatedAt: Date?

    init(profile: PersonalProfile) {
        id = profile.id ?? UUID()
        firstName = profile.firstName
        lastName = profile.lastName
        documentNumber = profile.documentNumber
        phone = profile.phone
        email = profile.email
        birthDate = profile.birthDate
        address = profile.address
        emergencyContact = profile.emergencyContact
        notes = profile.notes
        countryCode = profile.countryCode
        countryName = profile.countryName
        createdAt = profile.createdAt
        updatedAt = profile.updatedAt
    }

    init?(id: String, data: [String: Any]) {
        guard let uuid = UUID(uuidString: id) else { return nil }
        self.id = uuid
        firstName = data["firstName"] as? String
        lastName = data["lastName"] as? String
        documentNumber = data["documentNumber"] as? String
        phone = data["phone"] as? String
        email = data["email"] as? String
        birthDate = (data["birthDate"] as? Timestamp)?.dateValue()
        address = data["address"] as? String
        emergencyContact = data["emergencyContact"] as? String
        notes = data["notes"] as? String
        countryCode = data["countryCode"] as? String
        countryName = data["countryName"] as? String
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = ["updatedAt": Timestamp(date: updatedAt ?? Date())]
        let strings: [String: String?] = [
            "firstName": firstName, "lastName": lastName, "documentNumber": documentNumber,
            "phone": phone, "email": email, "address": address,
            "emergencyContact": emergencyContact, "notes": notes,
            "countryCode": countryCode, "countryName": countryName
        ]
        strings.forEach { if let value = $0.value { data[$0.key] = value } }
        if let birthDate { data["birthDate"] = Timestamp(date: birthDate) }
        if let createdAt { data["createdAt"] = Timestamp(date: createdAt) }
        return data
    }
}

enum FirebaseSyncError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        "Firebase aún no está configurado. Añade GoogleService-Info.plist al target de la aplicación."
    }
}

struct AccountSession: Sendable {
    let userID: String
    let email: String?
    let isAnonymous: Bool
}

actor FirebaseProfileService {
    static let shared = FirebaseProfileService()

    func synchronize(localProfiles: [CloudProfile]) async throws -> [CloudProfile] {
        guard FirebaseApp.app() != nil else { throw FirebaseSyncError.notConfigured }
        let userID = try await authenticatedUserID()
        let collection = Firestore.firestore().collection("users").document(userID).collection("profiles")

        for profile in localProfiles {
            try Task.checkCancellation()
            try await collection.document(profile.id.uuidString).setData(profile.firestoreData, merge: true)
        }

        let snapshot = try await collection.getDocuments()
        return snapshot.documents.compactMap { CloudProfile(id: $0.documentID, data: $0.data()) }
    }

    func currentSession(createAnonymousIfNeeded: Bool = false) async throws -> AccountSession? {
        try requireConfiguration()
        if let user = Auth.auth().currentUser {
            return AccountSession(userID: user.uid, email: user.email, isAnonymous: user.isAnonymous)
        }
        guard createAnonymousIfNeeded else { return nil }
        let user = try await Auth.auth().signInAnonymously().user
        return AccountSession(userID: user.uid, email: user.email, isAnonymous: true)
    }

    func register(email: String, password: String) async throws -> AccountSession {
        try requireConfiguration()
        let auth = Auth.auth()
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        let user: User
        if let current = auth.currentUser, current.isAnonymous {
            user = try await current.link(with: credential).user
        } else {
            user = try await auth.createUser(withEmail: email, password: password).user
        }
        return AccountSession(userID: user.uid, email: user.email, isAnonymous: user.isAnonymous)
    }

    func signIn(email: String, password: String) async throws -> AccountSession {
        try requireConfiguration()
        let user = try await Auth.auth().signIn(withEmail: email, password: password).user
        return AccountSession(userID: user.uid, email: user.email, isAnonymous: user.isAnonymous)
    }

    func signOut() throws {
        try requireConfiguration()
        try Auth.auth().signOut()
    }

    func deleteCurrentAccount() async throws {
        try requireConfiguration()
        guard let user = Auth.auth().currentUser else { return }
        let collection = Firestore.firestore().collection("users").document(user.uid).collection("profiles")
        let snapshot = try await collection.getDocuments()
        for document in snapshot.documents {
            try Task.checkCancellation()
            try await document.reference.delete()
        }
        try await user.delete()
    }

    private func authenticatedUserID() async throws -> String {
        if let user = Auth.auth().currentUser { return user.uid }
        return try await Auth.auth().signInAnonymously().user.uid
    }

    private func requireConfiguration() throws {
        guard FirebaseApp.app() != nil else { throw FirebaseSyncError.notConfigured }
    }
}
