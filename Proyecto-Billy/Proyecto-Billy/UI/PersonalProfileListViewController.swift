import CoreData
import UIKit

final class PersonalProfileListViewController: UITableViewController, UISearchResultsUpdating {
    private enum ProfileFilter: String, CaseIterable {
        case all = "Todos"
        case complete = "Completos"
        case incomplete = "Incompletos"
    }

    private enum ProfileSort: String, CaseIterable {
        case lastName = "Apellido"
        case recentlyUpdated = "Actualización"
    }

    private let searchController = UISearchController(searchResultsController: nil)
    private var selectedFilter: ProfileFilter = .all
    private var selectedSort: ProfileSort = .lastName
    private lazy var resultsController: NSFetchedResultsController<PersonalProfile> = {
        let controller = PersonalProfileRepository.shared.makeFetchedResultsController()
        controller.delegate = self
        return controller
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "No hay perfiles\nToca + para registrar el primero."
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItems = [UIBarButtonItem(
            systemItem: .add,
            primaryAction: UIAction { [weak self] _ in self?.showForm() }
        ), UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"), menu: makeOptionsMenu())]
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Nombre, DNI, teléfono o correo"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ProfileCell")
        tableView.accessibilityIdentifier = "profiles-table"
        do {
            try resultsController.performFetch()
            updateEmptyState()
        } catch {
            showError(error, title: "No se pudieron cargar los perfiles")
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        applyQuery()
    }

    private func makeOptionsMenu() -> UIMenu {
        let filters = ProfileFilter.allCases.map { filter in
            UIAction(title: filter.rawValue, state: filter == selectedFilter ? .on : .off) { [weak self] _ in
                self?.selectedFilter = filter
                self?.refreshOptions()
            }
        }
        let sorts = ProfileSort.allCases.map { sort in
            UIAction(title: sort.rawValue, state: sort == selectedSort ? .on : .off) { [weak self] _ in
                self?.selectedSort = sort
                self?.refreshOptions()
            }
        }
        return UIMenu(children: [UIMenu(title: "Mostrar", options: .displayInline, children: filters), UIMenu(title: "Ordenar por", children: sorts)])
    }

    private func refreshOptions() {
        navigationItem.rightBarButtonItems?[1].menu = makeOptionsMenu()
        applyQuery()
    }

    private func applyQuery() {
        let request = resultsController.fetchRequest
        var predicates: [NSPredicate] = []
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !query.isEmpty {
            predicates.append(NSPredicate(
                format: "firstName CONTAINS[cd] %@ OR lastName CONTAINS[cd] %@ OR documentNumber CONTAINS[cd] %@ OR phone CONTAINS[cd] %@ OR email CONTAINS[cd] %@",
                query, query, query, query, query
            ))
        }
        let requiredFields = ["firstName", "lastName", "documentNumber", "phone", "email", "address", "emergencyContact"]
        let completePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: requiredFields.map {
            NSPredicate(format: "%K != nil AND %K != ''", $0, $0)
        })
        if selectedFilter == .complete { predicates.append(completePredicate) }
        if selectedFilter == .incomplete { predicates.append(NSCompoundPredicate(notPredicateWithSubpredicate: completePredicate)) }
        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = selectedSort == .lastName
            ? [NSSortDescriptor(key: #keyPath(PersonalProfile.lastName), ascending: true), NSSortDescriptor(key: #keyPath(PersonalProfile.firstName), ascending: true)]
            : [NSSortDescriptor(key: #keyPath(PersonalProfile.updatedAt), ascending: false)]
        do {
            try resultsController.performFetch()
            tableView.reloadData()
            updateEmptyState()
        } catch {
            showError(error, title: "No se pudo aplicar la búsqueda")
        }
    }

    private func showForm(profile: PersonalProfile? = nil) {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "profileForm") as? PersonalProfileFormViewController else {
            return assertionFailure("PersonalProfileFormViewController no está configurado en Main.storyboard")
        }
        controller.profile = profile
        navigationController?.pushViewController(controller, animated: true)
    }

    private func updateEmptyState() {
        tableView.backgroundView = (resultsController.fetchedObjects?.isEmpty ?? true) ? emptyLabel : nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        resultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        resultsController.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath)
        let profile = resultsController.object(at: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = profile.fullName.isEmpty ? "Sin nombre" : profile.fullName
        content.secondaryText = [profile.documentNumber, profile.phone]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        content.image = ProfilePhotoStore.shared.image(for: profile.id) ?? UIImage(systemName: "person.crop.circle.fill")
        content.imageProperties.maximumSize = CGSize(width: 44, height: 44)
        content.imageProperties.cornerRadius = 22
        content.imageProperties.tintColor = AppStyle.accent
        cell.contentConfiguration = content
        cell.accessoryType = .none
        cell.accessoryView = makeProfileActionsButton(for: profile)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showForm(profile: resultsController.object(at: indexPath))
    }

    private func makeProfileActionsButton(for profile: PersonalProfile) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.accessibilityLabel = "Acciones para \(profile.fullName.isEmpty ? "el perfil" : profile.fullName)"

        let editAction = UIAction(title: "Editar", image: UIImage(systemName: "pencil")) { [weak self] _ in
            self?.showForm(profile: profile)
        }
        let shareAction = UIAction(title: "Compartir", image: UIImage(systemName: "square.and.arrow.up")) { [weak self, weak button] _ in
            guard let self, let button else { return }
            share(profile, from: button)
        }
        let deleteAction = UIAction(
            title: "Eliminar",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.confirmDeletion(of: profile)
        }
        button.menu = UIMenu(children: [editAction, shareAction, deleteAction])
        button.showsMenuAsPrimaryAction = true
        return button
    }

    private func share(_ profile: PersonalProfile, from sourceView: UIView) {
        var items: [Any] = [profile.shareText]
        if let photo = ProfilePhotoStore.shared.image(for: profile.id) {
            items.append(photo)
        }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = sourceView
        present(activity, animated: true)
    }

    private func confirmDeletion(
        of profile: PersonalProfile,
        completion: ((Bool) -> Void)? = nil
    ) {
        let profileName = profile.fullName.isEmpty ? "este perfil" : profile.fullName
        let alert = UIAlertController(
            title: "Eliminar perfil",
            message: "¿Seguro que deseas eliminar a \(profileName)? Se borrará del dispositivo y del respaldo de Firebase. Esta acción no se puede deshacer.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in
            completion?(false)
        })
        alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { [weak self] _ in
            guard let self else {
                completion?(false)
                return
            }
            deleteProfileFromDeviceAndFirebase(profile, completion: completion)
        })
        present(alert, animated: true)
    }

    private func deleteProfileFromDeviceAndFirebase(
        _ profile: PersonalProfile,
        completion: ((Bool) -> Void)?
    ) {
        let profileID = profile.id
        Task { [weak self] in
            guard let self else {
                completion?(false)
                return
            }

            if let profileID {
                do {
                    try await FirebaseProfileService.shared.deleteProfile(id: profileID)
                } catch {
                    showError(error, title: "No se pudo eliminar de Firebase")
                    completion?(false)
                    return
                }
            }

            do {
                try PersonalProfileRepository.shared.delete(profile)
                ProfilePhotoStore.shared.delete(for: profileID)
                completion?(true)
            } catch {
                showError(error, title: "No se pudo eliminar del dispositivo")
                completion?(false)
            }
        }
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: "Eliminar") { [weak self] _, _, completion in
            guard let self else { return completion(false) }
            let profile = resultsController.object(at: indexPath)
            confirmDeletion(of: profile, completion: completion)
        }
        action.image = UIImage(systemName: "trash")
        let configuration = UISwipeActionsConfiguration(actions: [action])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .normal, title: "Compartir") { [weak self] _, sourceView, completion in
            guard let self else { return completion(false) }
            let profile = resultsController.object(at: indexPath)
            share(profile, from: sourceView)
            completion(true)
        }
        action.backgroundColor = AppStyle.accent
        action.image = UIImage(systemName: "square.and.arrow.up")
        return UISwipeActionsConfiguration(actions: [action])
    }
}

extension PersonalProfileListViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        switch type {
        case .insert:
            if let newIndexPath { tableView.insertRows(at: [newIndexPath], with: .automatic) }
        case .delete:
            if let indexPath { tableView.deleteRows(at: [indexPath], with: .automatic) }
        case .update:
            if let indexPath { tableView.reloadRows(at: [indexPath], with: .automatic) }
        case .move:
            if let indexPath, let newIndexPath { tableView.moveRow(at: indexPath, to: newIndexPath) }
        @unknown default:
            tableView.reloadData()
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        tableView.endUpdates()
        updateEmptyState()
    }
}
