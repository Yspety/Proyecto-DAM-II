import UIKit

enum AppStyle {
    static let accent = UIColor(red: 0.12, green: 0.43, blue: 0.91, alpha: 1)
    static let background = UIColor.systemGroupedBackground
    static let cardBackground = UIColor.secondarySystemGroupedBackground

    static func configureAppearance() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithDefaultBackground()
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        navigation.titleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().tintColor = accent

        UISegmentedControl.appearance().selectedSegmentTintColor = accent
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
    }
}

extension NumberFormatter {
    static let penCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "PEN"
        formatter.locale = Locale(identifier: "es_PE")
        return formatter
    }()
}

extension DateFormatter {
    static let expenseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateStyle = .medium
        return formatter
    }()
}

extension UIViewController {
    func showError(_ error: Error, title: String = "Ocurrió un problema") {
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }
}
