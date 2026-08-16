import UIKit

final class PersonalProfileFormViewController: UIViewController {
    @IBOutlet private weak var firstNameField: UITextField!
    @IBOutlet private weak var lastNameField: UITextField!
    @IBOutlet private weak var documentField: UITextField!
    @IBOutlet private weak var phoneField: UITextField!
    @IBOutlet private weak var emailField: UITextField!
    @IBOutlet private weak var addressField: UITextField!
    @IBOutlet private weak var emergencyField: UITextField!
    @IBOutlet private weak var countryButton: UIButton!
    @IBOutlet private weak var birthDatePicker: UIDatePicker!
    @IBOutlet private weak var notesView: UITextView!
    @IBOutlet private weak var photoView: UIImageView!
    @IBOutlet private weak var photoButton: UIButton!

    var profile: PersonalProfile?
    private var selectedCountry: Country?
    private var selectedPhoto: UIImage?

    private lazy var documentErrorLabel = makeValidationLabel()
    private lazy var phoneErrorLabel = makeValidationLabel()
    private lazy var emailErrorLabel = makeValidationLabel()
    private lazy var birthDateErrorLabel = makeValidationLabel()
    private lazy var emergencyErrorLabel = makeValidationLabel()

    private let dniLength = 8
    private let phoneLength = 9

    private var latestAdultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = profile == nil ? "Nuevo perfil" : "Editar perfil"
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .never
        configureControls()
        populateIfNeeded()
        configureLiveValidation()
        refreshValidation(showErrors: false)
    }

    private func configureControls() {
        photoView.image = UIImage(systemName: "person.crop.circle.fill")
        photoView.tintColor = AppStyle.accent
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = 55
        photoView.layer.borderWidth = 2
        photoView.layer.borderColor = AppStyle.accent.cgColor
        photoButton.menu = makePhotoMenu()
        photoButton.showsMenuAsPrimaryAction = true
        documentField.delegate = self
        phoneField.delegate = self
        emergencyField.delegate = self
        documentField.keyboardType = .numberPad
        phoneField.keyboardType = .numberPad
        emergencyField.keyboardType = .numberPad
        phoneField.placeholder = "Teléfono *"
        emergencyField.placeholder = "Contacto de emergencia *"
        birthDatePicker.maximumDate = Date()
        if profile == nil {
            birthDatePicker.date = latestAdultBirthDate
        }
        notesView.layer.cornerRadius = 10
        notesView.layer.borderWidth = 1
        notesView.layer.borderColor = UIColor.separator.cgColor
        notesView.accessibilityLabel = "Notas"
    }

    private func makePhotoMenu() -> UIMenu {
        var actions: [UIAction] = [UIAction(title: "Elegir de la galería", image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in
            self?.presentImagePicker(source: .photoLibrary)
        }]
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actions.insert(UIAction(title: "Tomar fotografía", image: UIImage(systemName: "camera")) { [weak self] _ in
                self?.presentImagePicker(source: .camera)
            }, at: 0)
        }
        return UIMenu(title: "Fotografía del perfil", children: actions)
    }

    private func populateIfNeeded() {
        guard let profile else { return }
        if let image = ProfilePhotoStore.shared.image(for: profile.id) {
            selectedPhoto = image
            photoView.image = image
            photoButton.setTitle("Cambiar fotografía", for: .normal)
        }
        firstNameField.text = profile.firstName
        lastNameField.text = profile.lastName
        documentField.text = profile.documentNumber
        phoneField.text = profile.phone
        emailField.text = profile.email
        addressField.text = profile.address
        emergencyField.text = profile.emergencyContact
        notesView.text = profile.notes
        birthDatePicker.date = profile.birthDate ?? latestAdultBirthDate
        if let name = profile.countryName, !name.isEmpty {
            countryButton.setTitle(name, for: .normal)
        }
    }

    private func save() {
        guard refreshValidation(showErrors: true) else {
            focusFirstInvalidField()
            return
        }

        guard let firstName = required(firstNameField),
              let lastName = required(lastNameField),
              let document = required(documentField),
              let phoneText = required(phoneField),
              let emergencyText = required(emergencyField) else { return }

        let phone = normalizedPhone(phoneText)
        let emergencyPhone = normalizedPhone(emergencyText)
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let input = PersonalProfileInput(
            firstName: firstName, lastName: lastName, documentNumber: document,
            phone: phone, email: email, birthDate: birthDatePicker.date,
            address: addressField.text, emergencyContact: emergencyPhone,
            notes: notesView.text,
            countryCode: selectedCountry?.cca2 ?? profile?.countryCode,
            countryName: selectedCountry?.name.common ?? profile?.countryName
        )
        do {
            let savedProfile: PersonalProfile
            if let profile {
                try PersonalProfileRepository.shared.update(profile, with: input)
                savedProfile = profile
            } else {
                savedProfile = try PersonalProfileRepository.shared.create(input)
            }
            if let selectedPhoto, let profileID = savedProfile.id {
                try ProfilePhotoStore.shared.save(selectedPhoto, for: profileID)
            }
            navigationController?.popViewController(animated: true)
        } catch PersonalProfileRepositoryError.duplicateDocumentNumber {
            showError("Ya existe un perfil registrado con este DNI.", in: documentErrorLabel)
            navigationItem.rightBarButtonItem?.isEnabled = false
            documentField.becomeFirstResponder()
        } catch {
            showError(error, title: "No se pudo guardar el perfil")
        }
    }

    @IBAction private func saveTapped(_ sender: UIBarButtonItem) {
        save()
    }

    @IBAction private func countryTapped(_ sender: UIButton) {
        showCountrySearch()
    }


    private func presentImagePicker(source: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    private func normalizedPhone(_ text: String?) -> String {
        text?.filter(\.isNumber) ?? ""
    }

    private func makeValidationLabel() -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.isHidden = true
        label.accessibilityTraits = .staticText
        return label
    }

    private func configureLiveValidation() {
        group(documentField, with: documentErrorLabel)
        group(phoneField, with: phoneErrorLabel)
        group(emailField, with: emailErrorLabel)
        group(birthDatePicker, with: birthDateErrorLabel)
        group(emergencyField, with: emergencyErrorLabel)

        [firstNameField, lastNameField, documentField, phoneField, emailField, emergencyField].forEach {
            $0?.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        }
        birthDatePicker.addTarget(self, action: #selector(birthDateDidChange), for: .valueChanged)
    }

    private func group(_ control: UIView, with errorLabel: UILabel) {
        guard let parentStack = control.superview as? UIStackView,
              let index = parentStack.arrangedSubviews.firstIndex(of: control) else { return }

        parentStack.removeArrangedSubview(control)
        control.removeFromSuperview()
        let fieldStack = UIStackView(arrangedSubviews: [control, errorLabel])
        fieldStack.axis = .vertical
        fieldStack.spacing = 4
        parentStack.insertArrangedSubview(fieldStack, at: index)
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        refreshValidation(showErrors: true, changedField: textField)
    }

    @objc private func birthDateDidChange() {
        refreshValidation(showErrors: true, changedField: nil, birthDateChanged: true)
    }

    @discardableResult
    private func refreshValidation(
        showErrors: Bool,
        changedField: UITextField? = nil,
        birthDateChanged: Bool = false
    ) -> Bool {
        let documentMessage = documentValidationMessage()
        let phoneMessage = phoneValidationMessage(phoneField.text)
        let emailMessage = emailValidationMessage()
        let birthDateMessage = isAdult(birthDatePicker.date) ? nil : "La persona debe ser mayor de edad."
        let emergencyMessage = phoneValidationMessage(emergencyField.text)
        let showAllErrors = showErrors && changedField == nil && !birthDateChanged

        update(
            documentErrorLabel,
            message: documentMessage,
            visible: showErrors && (changedField === documentField || showAllErrors)
        )
        update(
            phoneErrorLabel,
            message: phoneMessage,
            visible: showErrors && (changedField === phoneField || showAllErrors)
        )
        update(
            emailErrorLabel,
            message: emailMessage,
            visible: showErrors && (changedField === emailField || showAllErrors)
        )
        update(
            birthDateErrorLabel,
            message: birthDateMessage,
            visible: showErrors && (birthDateChanged || showAllErrors)
        )
        update(
            emergencyErrorLabel,
            message: emergencyMessage,
            visible: showErrors && (changedField === emergencyField || showAllErrors)
        )

        let isValid = required(firstNameField) != nil
            && required(lastNameField) != nil
            && documentMessage == nil
            && phoneMessage == nil
            && emailMessage == nil
            && birthDateMessage == nil
            && emergencyMessage == nil
        navigationItem.rightBarButtonItem?.isEnabled = isValid
        return isValid
    }

    private func documentValidationMessage() -> String? {
        guard let document = required(documentField),
              document.count == dniLength,
              document.allSatisfy(\.isNumber) else {
            return "Debe contener 8 dígitos."
        }
        do {
            let isAvailable = try PersonalProfileRepository.shared.isDocumentNumberAvailable(
                document,
                excluding: profile
            )
            return isAvailable ? nil : "Ya existe un perfil registrado con este DNI."
        } catch {
            return "No se pudo validar el DNI. Inténtalo nuevamente."
        }
    }

    private func phoneValidationMessage(_ text: String?) -> String? {
        let number = normalizedPhone(text)
        return number.count == phoneLength && number.allSatisfy(\.isNumber)
            ? nil
            : "Debe contener 9 dígitos."
    }

    private func emailValidationMessage() -> String? {
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return email.isEmpty || isValidEmail(email) ? nil : "Correo electrónico no válido."
    }

    private func update(_ label: UILabel, message: String?, visible: Bool) {
        guard visible else { return }
        label.text = message
        label.isHidden = message == nil
    }

    private func showError(_ message: String, in label: UILabel) {
        label.text = message
        label.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func focusFirstInvalidField() {
        if required(firstNameField) == nil {
            firstNameField.becomeFirstResponder()
            return
        }
        if required(lastNameField) == nil {
            lastNameField.becomeFirstResponder()
            return
        }
        if documentValidationMessage() != nil {
            documentField.becomeFirstResponder()
            return
        }
        if phoneValidationMessage(phoneField.text) != nil {
            phoneField.becomeFirstResponder()
            return
        }
        if emailValidationMessage() != nil {
            emailField.becomeFirstResponder()
            return
        }
        if phoneValidationMessage(emergencyField.text) != nil {
            emergencyField.becomeFirstResponder()
        }
    }

    private func isAdult(_ birthDate: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let normalizedBirthDate = calendar.startOfDay(for: birthDate)
        guard let eighteenthBirthday = calendar.date(byAdding: .year, value: 18, to: normalizedBirthDate) else {
            return false
        }
        return eighteenthBirthday <= today
    }

    private func isValidEmail(_ email: String) -> Bool {
        email.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func required(_ field: UITextField) -> String? {
        let value = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private func showCountrySearch() {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "countrySearch") as? CountrySearchViewController else {
            return assertionFailure("CountrySearchViewController no está configurado en Main.storyboard")
        }
        controller.onSelection = { [weak self] country in
            self?.selectedCountry = country
            self?.countryButton.setTitle(country.displayName, for: .normal)
        }
        navigationController?.pushViewController(controller, animated: true)
    }

}

extension PersonalProfileFormViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard textField === documentField || textField === phoneField || textField === emergencyField else {
            return true
        }
        guard string.allSatisfy(\.isNumber) else { return false }
        guard let currentText = textField.text,
              let swiftRange = Range(range, in: currentText) else {
            return false
        }
        let updatedText = currentText.replacingCharacters(in: swiftRange, with: string)
        let maximumLength = textField === documentField ? dniLength : phoneLength
        return updatedText.count <= maximumLength
    }
}

extension PersonalProfileFormViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        selectedPhoto = image
        photoView.image = image
        photoButton.setTitle("Cambiar fotografía", for: .normal)
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
