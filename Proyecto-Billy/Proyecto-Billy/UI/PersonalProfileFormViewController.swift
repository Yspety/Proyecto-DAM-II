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
        birthDatePicker.maximumDate = latestAdultBirthDate
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
        birthDatePicker.date = min(profile.birthDate ?? latestAdultBirthDate, latestAdultBirthDate)
        if let name = profile.countryName, !name.isEmpty {
            countryButton.setTitle(name, for: .normal)
        }
    }

    private func save() {
        guard let firstName = required(firstNameField) else { return showValidation("Ingresa los nombres.", focus: firstNameField) }
        guard let lastName = required(lastNameField) else { return showValidation("Ingresa los apellidos.", focus: lastNameField) }
        guard let document = required(documentField) else { return showValidation("Ingresa el documento.", focus: documentField) }
        guard document.count == dniLength, document.allSatisfy(\.isNumber) else {
            return showValidation("El DNI debe contener exactamente 8 dígitos.", focus: documentField)
        }
        guard let phoneText = required(phoneField) else {
            return showValidation("Ingresa el número de teléfono.", focus: phoneField)
        }
        let phone = normalizedPhone(phoneText)
        guard phone.count == phoneLength, phone.allSatisfy(\.isNumber) else {
            return showValidation("El teléfono debe contener exactamente 9 dígitos.", focus: phoneField)
        }
        guard let emergencyText = required(emergencyField) else {
            return showValidation("Ingresa el contacto de emergencia.", focus: emergencyField)
        }
        let emergencyPhone = normalizedPhone(emergencyText)
        guard emergencyPhone.count == phoneLength, emergencyPhone.allSatisfy(\.isNumber) else {
            return showValidation("El contacto de emergencia debe contener exactamente 9 dígitos.", focus: emergencyField)
        }
        guard isAdult(birthDatePicker.date) else {
            return showValidation("La persona debe tener 18 años o más.", focus: birthDatePicker)
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

    private func showValidation(_ message: String, focus: UIView) {
        let alert = UIAlertController(title: "Revisa los datos", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Corregir", style: .default) { _ in focus.becomeFirstResponder() })
        present(alert, animated: true)
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
