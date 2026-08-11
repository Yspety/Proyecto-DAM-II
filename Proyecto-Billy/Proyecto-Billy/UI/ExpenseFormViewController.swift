import UIKit

final class ExpenseFormViewController: UIViewController {
    private let expense: Expense?
    private var selectedCategory: ExpenseCategory = .food

    private let titleField = UITextField()
    private let amountField = UITextField()
    private let categoryButton = UIButton(type: .system)
    private let datePicker = UIDatePicker()
    private let noteView = UITextView()

    init(expense: Expense? = nil) {
        self.expense = expense
        super.init(nibName: nil, bundle: nil)
        title = expense == nil ? "Nuevo gasto" : "Editar gasto"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no está disponible")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .never
        configureFields()
        configureLayout()
        populateIfNeeded()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Guardar",
            primaryAction: UIAction { [weak self] _ in self?.save() }
        )
    }

    private func configureFields() {
        titleField.placeholder = "Ej. Almuerzo"
        titleField.borderStyle = .roundedRect
        titleField.textContentType = .name
        titleField.returnKeyType = .next
        titleField.accessibilityIdentifier = "expense-title"

        amountField.placeholder = "0.00"
        amountField.borderStyle = .roundedRect
        amountField.keyboardType = .decimalPad
        amountField.accessibilityIdentifier = "expense-amount"

        categoryButton.configuration = .bordered()
        categoryButton.contentHorizontalAlignment = .leading
        categoryButton.showsMenuAsPrimaryAction = true
        categoryButton.accessibilityIdentifier = "expense-category"
        updateCategoryMenu()

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.maximumDate = Date()
        datePicker.accessibilityIdentifier = "expense-date"

        noteView.font = .preferredFont(forTextStyle: .body)
        noteView.backgroundColor = .secondarySystemGroupedBackground
        noteView.layer.cornerRadius = 10
        noteView.layer.borderWidth = 1
        noteView.layer.borderColor = UIColor.separator.cgColor
        noteView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        noteView.accessibilityLabel = "Nota opcional"
        noteView.accessibilityIdentifier = "expense-note"
        noteView.heightAnchor.constraint(equalToConstant: 110).isActive = true
    }

    private func configureLayout() {
        let stack = UIStackView(arrangedSubviews: [
            makeField(label: "Descripción", control: titleField),
            makeField(label: "Monto en soles", control: amountField),
            makeField(label: "Categoría", control: categoryButton),
            makeField(label: "Fecha", control: datePicker),
            makeField(label: "Nota", control: noteView)
        ])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    private func makeField(label text: String, control: UIView) -> UIStackView {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = 7
        return stack
    }

    private func populateIfNeeded() {
        guard let expense else { return }
        titleField.text = expense.title
        amountField.text = String(format: "%.2f", expense.amount)
        selectedCategory = ExpenseCategory(rawValue: expense.safeCategory) ?? .other
        datePicker.date = expense.date ?? Date()
        noteView.text = expense.note
        updateCategoryMenu()
    }

    private func updateCategoryMenu() {
        categoryButton.setTitle(selectedCategory.rawValue, for: .normal)
        categoryButton.setImage(UIImage(systemName: selectedCategory.iconName), for: .normal)
        categoryButton.menu = UIMenu(children: ExpenseCategory.allCases.map { category in
            UIAction(
                title: category.rawValue,
                image: UIImage(systemName: category.iconName),
                state: category == selectedCategory ? .on : .off
            ) { [weak self] _ in
                self?.selectedCategory = category
                self?.updateCategoryMenu()
            }
        })
    }

    private func save() {
        guard let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return showValidation(message: "Ingresa una descripción para el gasto.", focus: titleField)
        }
        let normalizedAmount = (amountField.text ?? "").replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalizedAmount), amount > 0 else {
            return showValidation(message: "Ingresa un monto mayor que cero.", focus: amountField)
        }

        do {
            if let expense {
                try ExpenseRepository.shared.update(
                    expense,
                    title: title,
                    amount: amount,
                    category: selectedCategory,
                    date: datePicker.date,
                    note: noteView.text
                )
            } else {
                try ExpenseRepository.shared.create(
                    title: title,
                    amount: amount,
                    category: selectedCategory,
                    date: datePicker.date,
                    note: noteView.text
                )
            }
            navigationController?.popViewController(animated: true)
        } catch {
            showError(error, title: "No se pudo guardar")
        }
    }

    private func showValidation(message: String, focus: UIView) {
        let alert = UIAlertController(title: "Revisa los datos", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Corregir", style: .default) { _ in focus.becomeFirstResponder() })
        present(alert, animated: true)
    }
}
