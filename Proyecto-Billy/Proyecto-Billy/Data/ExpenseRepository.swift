import CoreData
import UIKit

@MainActor
final class ExpenseRepository {
    static let shared = ExpenseRepository()
    static let didChange = Notification.Name("ExpenseRepository.didChange")

    var viewContext: NSManagedObjectContext {
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            preconditionFailure("AppDelegate no está disponible")
        }
        return delegate.persistentContainer.viewContext
    }

    private init() {}

    func makeFetchedResultsController() -> NSFetchedResultsController<Expense> {
        let request = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Expense.date), ascending: false)]
        return NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    func fetchAll() throws -> [Expense] {
        let request = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Expense.date), ascending: false)]
        return try viewContext.fetch(request)
    }

    @discardableResult
    func create(title: String, amount: Double, category: ExpenseCategory, date: Date, note: String?) throws -> Expense {
        let expense = Expense(context: viewContext)
        expense.id = UUID()
        apply(title: title, amount: amount, category: category, date: date, note: note, to: expense)
        try save()
        return expense
    }

    func update(_ expense: Expense, title: String, amount: Double, category: ExpenseCategory, date: Date, note: String?) throws {
        apply(title: title, amount: amount, category: category, date: date, note: note, to: expense)
        try save()
    }

    func delete(_ expense: Expense) throws {
        viewContext.delete(expense)
        try save()
    }

    private func apply(title: String, amount: Double, category: ExpenseCategory, date: Date, note: String?, to expense: Expense) {
        expense.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.amount = amount
        expense.category = category.rawValue
        expense.date = date
        expense.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() throws {
        guard viewContext.hasChanges else { return }
        try viewContext.save()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}
