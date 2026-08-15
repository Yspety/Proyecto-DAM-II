import UIKit

final class FirebaseSyncViewController: UIViewController {
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var detailLabel: UILabel!
    @IBOutlet private weak var syncButton: UIButton!
    @IBOutlet private weak var indicator: UIActivityIndicatorView!

    private var syncTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .always
        statusLabel.text = "Respaldo en Firebase"
        detailLabel.text = "Sincroniza los perfiles locales con Cloud Firestore."
        indicator.hidesWhenStopped = true
    }

    deinit { syncTask?.cancel() }

    @IBAction private func syncTapped(_ sender: UIButton) {
        startSync()
    }

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
