import LocalAuthentication

enum BiometricAuthResult {
    case authenticated
    case unavailable(String)
    case failed(String)
}

@MainActor
final class BiometricAuthService {
    static let shared = BiometricAuthService()

    private init() {}

    func authenticate(reason: String) async -> BiometricAuthResult {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable(unavailableMessage(for: error))
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success ? .authenticated : .failed("No se pudo verificar tu identidad.")
        } catch {
            let code = LAError.Code(rawValue: (error as NSError).code)
            if code == .userCancel || code == .systemCancel || code == .appCancel {
                return .failed("La autenticación fue cancelada.")
            }
            return .failed("No se pudo autenticar: \(error.localizedDescription)")
        }
    }

    func biometricName() -> String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Biometría"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometría"
        }
    }

    private func unavailableMessage(for error: NSError?) -> String {
        switch error.flatMap({ LAError.Code(rawValue: $0.code) }) {
        case .biometryNotEnrolled:
            return "Configura Face ID o Touch ID en Ajustes para proteger tus datos."
        case .biometryLockout:
            return "La biometría está bloqueada temporalmente. Desbloquea el dispositivo e inténtalo de nuevo."
        case .biometryNotAvailable:
            return "Este dispositivo no tiene autenticación biométrica disponible."
        default:
            return error?.localizedDescription ?? "La autenticación biométrica no está disponible."
        }
    }
}
