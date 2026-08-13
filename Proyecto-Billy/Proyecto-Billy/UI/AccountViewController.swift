import FirebaseAuth
import UIKit

final class AccountViewController: UIViewController {
    private let statusLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let registerButton = UIButton(type: .system)
    private let signInButton = UIButton(type: .system)
    private let signOutButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let deleteLocalButton = UIButton(type: .system)
    private let indicator = UIActivityIndicatorView(style: .medium)
    private var accountTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .always
        configureViews()
        refreshSession(createAnonymousIfNeeded: true)
    }

    deinit { accountTask?.cancel() }

    private func configureViews() {
        let icon = UIImageView(image: UIImage(systemName: "person.badge.key.fill"))
        icon.tintColor = AppStyle.accent
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        configure(emailField, placeholder: "Correo electrónico", contentType: .emailAddress)
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        configure(passwordField, placeholder: "Contraseña (mínimo 6 caracteres)", contentType: .password)
        passwordField.isSecureTextEntry = true

        configure(registerButton, title: "Crear o vincular cuenta", image: "person.badge.plus") { [weak self] in
            self?.authenticate(registering: true)
        }
        configure(signInButton, title: "Iniciar sesión", image: "person.crop.circle.badge.checkmark") { [weak self] in
            self?.authenticate(registering: false)
        }
        configure(signOutButton, title: "Cerrar sesión", image: "rectangle.portrait.and.arrow.right") { [weak self] in
            self?.signOut()
        }
        configure(deleteButton, title: "Eliminar cuenta y respaldo", image: "trash") { [weak self] in
            self?.confirmAccountDeletion()
        }
        deleteButton.configuration?.baseForegroundColor = .systemRed
        configure(deleteLocalButton, title: "Eliminar datos de este dispositivo", image: "iphone.slash") { [weak self] in
            self?.confirmLocalDeletion()
        }
        deleteLocalButton.configuration?.baseForegroundColor = .systemOrange
        indicator.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            icon, statusLabel, emailField, passwordField,
            registerButton, signInButton, signOutButton, deleteButton, deleteLocalButton, indicator
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -12)
        ])
    }

    private func configure(_ field: UITextField, placeholder: String, contentType: UITextContentType) {
        field.placeholder = placeholder
        field.textContentType = contentType
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.heightAnchor.constraint(equalToConstant: 46).isActive = true
    }

    private func configure(_ button: UIButton, title: String, image: String, action: @escaping () -> Void) {
        button.configuration = .filled()
        button.configuration?.title = title
        button.configuration?.image = UIImage(systemName: image)
        button.configuration?.imagePadding = 8
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
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
