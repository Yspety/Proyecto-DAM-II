import FirebaseAuth
import UIKit

final class AccountViewController: UIViewController {
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var emailField: UITextField!
    @IBOutlet private weak var passwordField: UITextField!
    @IBOutlet private weak var registerButton: UIButton!
    @IBOutlet private weak var signInButton: UIButton!
    @IBOutlet private weak var signOutButton: UIButton!
    @IBOutlet private weak var deleteButton: UIButton!
    @IBOutlet private weak var deleteLocalButton: UIButton!
    @IBOutlet private weak var indicator: UIActivityIndicatorView!

    private var accountTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .always
        indicator.hidesWhenStopped = true
        refreshSession(createAnonymousIfNeeded: true)
    }

    deinit { accountTask?.cancel() }

    @IBAction private func registerTapped(_ sender: UIButton) {
        authenticate(registering: true)
    }

    @IBAction private func signInTapped(_ sender: UIButton) {
        authenticate(registering: false)
    }

    @IBAction private func signOutTapped(_ sender: UIButton) {
        signOut()
    }

    @IBAction private func deleteAccountTapped(_ sender: UIButton) {
        confirmAccountDeletion()
    }

    @IBAction private func deleteLocalTapped(_ sender: UIButton) {
        confirmLocalDeletion()
    }

    private func authenticate(registering: Bool) {
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordField.text ?? ""
        guard email.contains("@"), password.count >= 6 else {
            showMessage("Ingresa un correo válido y una contraseña de al menos 6 caracteres.")
            return
        }
        runAccountOperation {
            if registering {
                return try await FirebaseProfileService.shared.register(email: email, password: password)
            }
            return try await FirebaseProfileService.shared.signIn(email: email, password: password)
        }
    }

    private func signOut() {
        setLoading(true)
        accountTask?.cancel()
        accountTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await FirebaseProfileService.shared.signOut()
                setLoading(false)
                updateUI(session: nil)
                showMessage("La sesión se cerró correctamente.")
            } catch {
                setLoading(false)
                showMessage(error.localizedDescription)
            }
        }
    }

    private func confirmAccountDeletion() {
        let alert = UIAlertController(
            title: "¿Eliminar cuenta?",
            message: "Se eliminarán la cuenta y todos sus perfiles respaldados en Firebase. Los datos locales permanecerán en este dispositivo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { [weak self] _ in
            self?.deleteAccount()
        })
        present(alert, animated: true)
    }

    private func confirmLocalDeletion() {
        let alert = UIAlertController(
            title: "¿Eliminar datos locales?",
            message: "Se borrarán definitivamente todos los perfiles y fotografías guardados en este dispositivo. La cuenta y el respaldo de Firebase no serán eliminados.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Eliminar del dispositivo", style: .destructive) { [weak self] _ in
            self?.deleteLocalData()
        })
        present(alert, animated: true)
    }

    private func deleteLocalData() {
        do {
            try ProfilePhotoStore.shared.deleteAll()
            try PersonalProfileRepository.shared.deleteAll()
            showMessage("Los perfiles y fotografías locales fueron eliminados. El respaldo remoto permanece disponible.")
        } catch {
            showMessage("No se pudieron eliminar todos los datos locales: \(error.localizedDescription)")
        }
    }

    private func deleteAccount() {
        setLoading(true)
        accountTask?.cancel()
        accountTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await FirebaseProfileService.shared.deleteCurrentAccount()
                setLoading(false)
                updateUI(session: nil)
                showMessage("La cuenta y su respaldo fueron eliminados.")
            } catch {
                setLoading(false)
                showMessage(readableMessage(for: error))
            }
        }
    }

    private func refreshSession(createAnonymousIfNeeded: Bool) {
        setLoading(true)
        accountTask?.cancel()
        accountTask = Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await FirebaseProfileService.shared.currentSession(
                    createAnonymousIfNeeded: createAnonymousIfNeeded
                )
                setLoading(false)
                updateUI(session: session)
            } catch {
                setLoading(false)
                showMessage(error.localizedDescription)
            }
        }
    }

    private func runAccountOperation(_ operation: @escaping () async throws -> AccountSession) {
        setLoading(true)
        accountTask?.cancel()
        accountTask = Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await operation()
                passwordField.text = nil
                setLoading(false)
                updateUI(session: session)
                showMessage("La cuenta está lista y tus próximos respaldos usarán esta sesión.")
            } catch {
                setLoading(false)
                showMessage(readableMessage(for: error))
            }
        }
    }

    private func updateUI(session: AccountSession?) {
        if let session {
            statusLabel.text = session.isAnonymous
                ? "Sesión temporal activa\nVincúlala con tu correo para conservar el acceso."
                : "Sesión activa\n\(session.email ?? session.userID)"
            emailField.isHidden = !session.isAnonymous
            passwordField.isHidden = !session.isAnonymous
            registerButton.isHidden = !session.isAnonymous
            signInButton.isHidden = !session.isAnonymous
            signOutButton.isHidden = session.isAnonymous
            deleteButton.isHidden = false
        } else {
            statusLabel.text = "No hay una sesión activa."
            emailField.isHidden = false
            passwordField.isHidden = false
            registerButton.isHidden = false
            signInButton.isHidden = false
            signOutButton.isHidden = true
            deleteButton.isHidden = true
        }
    }

    private func setLoading(_ loading: Bool) {
        loading ? indicator.startAnimating() : indicator.stopAnimating()
        [registerButton, signInButton, signOutButton, deleteButton, deleteLocalButton].forEach { $0.isEnabled = !loading }
    }

    private func readableMessage(for error: Error) -> String {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .emailAlreadyInUse: return "Ese correo ya está registrado. Usa Iniciar sesión."
        case .wrongPassword, .invalidCredential: return "El correo o la contraseña no son correctos."
        case .requiresRecentLogin: return "Por seguridad, inicia sesión nuevamente antes de eliminar la cuenta."
        case .networkError: return "No se pudo conectar con Firebase. Revisa tu conexión."
        default: return error.localizedDescription
        }
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "Cuenta", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }
}
