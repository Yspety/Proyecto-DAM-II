import CoreData

@objc(Expense)
final class Expense: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var amount: Double
    @NSManaged var category: String?
    @NSManaged var date: Date?
    @NSManaged var note: String?
}

extension Expense {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Expense> {
        NSFetchRequest<Expense>(entityName: "Expense")
    }

    var safeTitle: String { title?.nilIfBlank ?? "Sin descripción" }
    var safeCategory: String { category?.nilIfBlank ?? ExpenseCategory.other.rawValue }
    var safeDate: Date { date ?? .distantPast }
    var formattedAmount: String {
        NumberFormatter.penCurrency.string(from: amount as NSNumber) ?? String(format: "S/ %.2f", amount)
    }
}

enum ExpenseCategory: String, CaseIterable {
    case food = "Comida"
    case transport = "Transporte"
    case home = "Hogar"
    case education = "Educación"
    case entertainment = "Entretenimiento"
    case other = "Otros"

    var iconName: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "bus.fill"
        case .home: "house.fill"
        case .education: "book.fill"
        case .entertainment: "gamecontroller.fill"
        case .other: "tag.fill"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
