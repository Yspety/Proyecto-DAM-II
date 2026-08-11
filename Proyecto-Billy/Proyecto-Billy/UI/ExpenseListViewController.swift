import CoreData
import UIKit

final class ExpenseListViewController: UITableViewController {
    private lazy var resultsController: NSFetchedResultsController<Expense> = {
        let controller = ExpenseRepository.shared.makeFetchedResultsController()
        controller.delegate = self
        return controller
    }()

    private let emptyState: UIStackView = {
        let image = UIImageView(image: UIImage(systemName: "wallet.bifold"))
        image.tintColor = AppStyle.accent
        image.contentMode = .scaleAspectFit
        image.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let title = UILabel()
        title.text = "Todavía no hay gastos"
        title.font = .preferredFont(forTextStyle: .title3)
        title.textAlignment = .center

        let message = UILabel()
        message.text = "Toca + para registrar tu primer movimiento."
        message.font = .preferredFont(forTextStyle: .body)
        message.textColor = .secondaryLabel
        message.textAlignment = .center
        message.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [image, title, message])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no está disponible")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .add,
            primaryAction: UIAction { [weak self] _ in self?.showForm() }
        )
        tableView.register(ExpenseCell.self, forCellReuseIdentifier: ExpenseCell.reuseIdentifier)
        tableView.rowHeight = 76
        tableView.accessibilityIdentifier = "expenses-table"
        loadExpenses()
    }

    private func loadExpenses() {
        do {
            try resultsController.performFetch()
            updateEmptyState()
        } catch {
            showError(error, title: "No se pudieron cargar los gastos")
        }
    }

    private func showForm(expense: Expense? = nil) {
        navigationController?.pushViewController(ExpenseFormViewController(expense: expense), animated: true)
    }

    private func updateEmptyState() {
        let isEmpty = resultsController.fetchedObjects?.isEmpty ?? true
        tableView.backgroundView = isEmpty ? emptyState : nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        resultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        resultsController.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ExpenseCell.reuseIdentifier, for: indexPath) as! ExpenseCell
        cell.configure(with: resultsController.object(at: indexPath))
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showForm(expense: resultsController.object(at: indexPath))
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let expense = resultsController.object(at: indexPath)
        let delete = UIContextualAction(style: .destructive, title: "Eliminar") { [weak self] _, _, completion in
            do {
                try ExpenseRepository.shared.delete(expense)
                completion(true)
            } catch {
                self?.showError(error, title: "No se pudo eliminar")
                completion(false)
            }
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

extension ExpenseListViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChange sectionInfo: any NSFetchedResultsSectionInfo,
        atSectionIndex sectionIndex: Int,
        for type: NSFetchedResultsChangeType
    ) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
        default:
            break
        }
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
            if let indexPath, let cell = tableView.cellForRow(at: indexPath) as? ExpenseCell {
                cell.configure(with: resultsController.object(at: indexPath))
            }
        case .move:
            if let indexPath { tableView.deleteRows(at: [indexPath], with: .automatic) }
            if let newIndexPath { tableView.insertRows(at: [newIndexPath], with: .automatic) }
        @unknown default:
            tableView.reloadData()
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        tableView.endUpdates()
        updateEmptyState()
    }
}

private final class ExpenseCell: UITableViewCell {
    static let reuseIdentifier = "ExpenseCell"

    func configure(with expense: Expense) {
        var content = defaultContentConfiguration()
        content.text = "\(expense.safeTitle) · \(expense.formattedAmount)"
        content.secondaryText = "\(expense.safeCategory) · \(DateFormatter.expenseDate.string(from: expense.safeDate))"
        content.image = UIImage(systemName: ExpenseCategory(rawValue: expense.safeCategory)?.iconName ?? ExpenseCategory.other.iconName)
        content.imageProperties.tintColor = AppStyle.accent
        content.prefersSideBySideTextAndSecondaryText = false
        contentConfiguration = content
        accessoryType = .disclosureIndicator
    }
}
