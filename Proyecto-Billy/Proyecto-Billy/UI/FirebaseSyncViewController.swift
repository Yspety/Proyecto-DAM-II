import UIKit

final class FirebaseSyncViewController: UIViewController {
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let syncButton = UIButton(type: .system)
    private let indicator = UIActivityIndicatorView(style: .medium)
    private var syncTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .always

        let icon = UIImageView(image: UIImage(systemName: "icloud.and.arrow.up.fill"))
        icon.tintColor = AppStyle.accent
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        statusLabel.text = "Respaldo en Firebase"
        statusLabel.font = .preferredFont(forTextStyle: .title2)
        statusLabel.textAlignment = .center
        detailLabel.text = "Sincroniza los perfiles locales con Cloud Firestore."
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        syncButton.configuration = .filled()
        syncButton.configuration?.title = "Sincronizar ahora"
        syncButton.configuration?.image = UIImage(systemName: "arrow.triangle.2.circlepath")
        syncButton.addAction(UIAction { [weak self] _ in self?.startSync() }, for: .touchUpInside)
        indicator.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [icon, statusLabel, detailLabel, indicator, syncButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -16)
        ])
    }

    deinit { syncTask?.cancel() }

    private func startSync() {
        syncTask?.cancel()
        indicator.startAnimating()
        syncButton.isEnabled = false
        detailLabel.text = "Subiendo y descargando perfiles..."

        syncTask = Task { [weak self] in
            guard let self else { return }
            do {
                let local = try PersonalProfileRepository.shared.fetchAll().map(CloudProfile.init)
                let remote = try await FirebaseProfileService.shared.synchronize(localProfiles: local)
                try Task.checkCancellation()
                try PersonalProfileRepository.shared.merge(remote)
                indicator.stopAnimating()
                syncButton.isEnabled = true
                detailLabel.text = "Sincronización completada: \(remote.count) perfiles respaldados."
            } catch is CancellationError {
                return
            } catch {
                indicator.stopAnimating()
                syncButton.isEnabled = true
                detailLabel.text = error.localizedDescription
            }
        }
    }
}
