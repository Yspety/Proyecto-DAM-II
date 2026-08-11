import UIKit

final class PlaceholderPageViewController: UIViewController {
    let pageIndex: Int
    private let descriptor: PageDescriptor

    init(descriptor: PageDescriptor, pageIndex: Int) {
        self.descriptor = descriptor
        self.pageIndex = pageIndex
        super.init(nibName: nil, bundle: nil)
        title = descriptor.title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no está disponible")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .always
        configureContent()
    }

    private func configureContent() {
        let card = UIView()
        card.backgroundColor = AppStyle.cardBackground
        card.layer.cornerRadius = 24
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.07
        card.layer.shadowRadius = 14
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: descriptor.iconName))
        icon.tintColor = AppStyle.accent
        icon.contentMode = .scaleAspectFit

        let heading = UILabel()
        heading.text = descriptor.title
        heading.font = .preferredFont(forTextStyle: .title1)
        heading.adjustsFontForContentSizeCategory = true
        heading.textAlignment = .center

        let message = UILabel()
        message.text = descriptor.message
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.textColor = .secondaryLabel
        message.textAlignment = .center
        message.numberOfLines = 0

        let phase = UILabel()
        phase.text = "Estructura preparada · Fase 1"
        phase.font = .preferredFont(forTextStyle: .caption1)
        phase.textColor = AppStyle.accent
        phase.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, heading, message, phase])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(card)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            card.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -32),
            icon.heightAnchor.constraint(equalToConstant: 72)
        ])
    }
}
