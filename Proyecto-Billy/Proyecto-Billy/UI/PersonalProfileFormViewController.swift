import UIKit

final class PersonalProfileFormViewController: UIViewController {
    private let profile: PersonalProfile?
    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let documentField = UITextField()
    private let phoneField = UITextField()
    private let emailField = UITextField()
    private let addressField = UITextField()
    private let emergencyField = UITextField()
    private let countryButton = UIButton(type: .system)
    private let birthDatePicker = UIDatePicker()
    private let notesView = UITextView()
    private var selectedCountry: Country?

    init(profile: PersonalProfile? = nil) {
        self.profile = profile
        super.init(nibName: nil, bundle: nil)
        title = profile == nil ? "Nuevo perfil" : "Editar perfil"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no está disponible") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .never
        configureControls()
        configureLayout()
        populateIfNeeded()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Guardar",
            primaryAction: UIAction { [weak self] _ in self?.save() }
        )
    }

    private func configureControls() {
        configure(firstNameField, placeholder: "Nombres", contentType: .givenName)
        configure(lastNameField, placeholder: "Apellidos", contentType: .familyName)
        configure(documentField, placeholder: "DNI o documento", keyboard: .numberPad)
        configure(phoneField, placeholder: "Teléfono", keyboard: .phonePad, contentType: .telephoneNumber)
        configure(emailField, placeholder: "Correo", keyboard: .emailAddress, contentType: .emailAddress)
        configure(addressField, placeholder: "Dirección", contentType: .fullStreetAddress)
        configure(emergencyField, placeholder: "Contacto de emergencia", contentType: .telephoneNumber)

        countryButton.configuration = .bordered()
        countryButton.configuration?.title = "Seleccionar país"
        countryButton.configuration?.image = UIImage(systemName: "globe.americas.fill")
        countryButton.contentHorizontalAlignment = .leading
        countryButton.addAction(UIAction { [weak self] _ in self?.showCountrySearch() }, for: .touchUpInside)

        birthDatePicker.datePickerMode = .date
        birthDatePicker.preferredDatePickerStyle = .compact
        birthDatePicker.maximumDate = Date()

        notesView.font = .preferredFont(forTextStyle: .body)
        notesView.backgroundColor = .secondarySystemGroupedBackground
        notesView.layer.cornerRadius = 10
        notesView.layer.borderWidth = 1
        notesView.layer.borderColor = UIColor.separator.cgColor
        notesView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        notesView.accessibilityLabel = "Notas"
    }

    private func configure(
        _ field: UITextField,
        placeholder: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil
    ) {
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.keyboardType = keyboard
        field.textContentType = contentType
        field.autocapitalizationType = keyboard == .emailAddress ? .none : .sentences
    }

    private func configureLayout() {
        let fields: [(String, UIView)] = [
            ("Nombres *", firstNameField), ("Apellidos *", lastNameField),
            ("Documento *", documentField), ("Teléfono", phoneField),
            ("Correo", emailField), ("Fecha de nacimiento", birthDatePicker),
            ("País (servicio REST)", countryButton), ("Dirección", addressField), ("Emergencia", emergencyField),
            ("Notas", notesView)
        ]
        let stack = UIStackView(arrangedSubviews: fields.map(makeField))
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -30)
        ])
    }

    private func makeField(_ item: (String, UIView)) -> UIStackView {
        let label = UILabel()
        label.text = item.0
        label.font = .preferredFont(forTextStyle: .headline)
        let stack = UIStackView(arrangedSubviews: [label, item.1])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }

    private func populateIfNeeded() {
        guard let profile else { return }
        firstNameField.text = profile.firstName
        lastNameField.text = profile.lastName
        documentField.text = profile.documentNumber
        phoneField.text = profile.phone
        emailField.text = profile.email
        addressField.text = profile.address
        emergencyField.text = profile.emergencyContact
        notesView.text = profile.notes
        birthDatePicker.date = profile.birthDate ?? Date()
        if let name = profile.countryName, !name.isEmpty {
            countryButton.configuration?.title = name
        }
    }

    private func save() {
        guard let firstName = required(firstNameField) else { return showValidation("Ingresa los nombres.", focus: firstNameField) }
        guard let lastName = required(lastNameField) else { return showValidation("Ingresa los apellidos.", focus: lastNameField) }
        guard let document = required(documentField) else { return showValidation("Ingresa el documento.", focus: documentField) }
        guard document.count == 8, document.allSatisfy(\.isNumber) else {
            return showValidation("El DNI debe contener exactamente 8 dígitos.", focus: documentField)
        }
        let phone = normalizedPhone(phoneField.text)
        guard phone.isEmpty || (7...15).contains(phone.filter(\.isNumber).count) else {
            return showValidation("El teléfono debe contener entre 7 y 15 dígitos.", focus: phoneField)
        }
        let emergencyPhone = normalizedPhone(emergencyField.text)
        guard emergencyPhone.isEmpty || (7...15).contains(emergencyPhone.filter(\.isNumber).count) else {
            return showValidation("El contacto de emergencia debe contener entre 7 y 15 dígitos.", focus: emergencyField)
        }
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard email.isEmpty || isValidEmail(email) else { return showValidation("Ingresa un correo válido.", focus: emailField) }

        let input = PersonalProfileInput(
            firstName: firstName, lastName: lastName, documentNumber: document,
            phone: phone, email: email, birthDate: birthDatePicker.date,
            address: addressField.text, emergencyContact: emergencyPhone,
            notes: notesView.text,
            countryCode: selectedCountry?.cca2 ?? profile?.countryCode,
            countryName: selectedCountry?.name.common ?? profile?.countryName
        )
        do {
            if let profile { try PersonalProfileRepository.shared.update(profile, with: input) }
            else { try PersonalProfileRepository.shared.create(input) }
            navigationController?.popViewController(animated: true)
        } catch {
            showError(error, title: "No se pudo guardar el perfil")
        }
    }

    private func normalizedPhone(_ text: String?) -> String {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prefix = value.hasPrefix("+") ? "+" : ""
        return prefix + value.filter(\.isNumber)
    }

    private func isValidEmail(_ email: String) -> Bool {
        email.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func required(_ field: UITextField) -> String? {
        let value = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private func showCountrySearch() {
        let controller = CountrySearchViewController()
        controller.onSelection = { [weak self] country in
            self?.selectedCountry = country
            self?.countryButton.configuration?.title = country.displayName
        }
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showValidation(_ message: String, focus: UIView) {
        let alert = UIAlertController(title: "Revisa los datos", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Corregir", style: .default) { _ in focus.becomeFirstResponder() })
        present(alert, animated: true)
    }
}
