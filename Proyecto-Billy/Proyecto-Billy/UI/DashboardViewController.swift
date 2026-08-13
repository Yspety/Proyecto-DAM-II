import UIKit

fileprivate struct ProfileGroup: Hashable {
    let title: String
    let iconName: String

    static let complete = ProfileGroup(title: "Completos", iconName: "checkmark.seal.fill")
    static let missingContact = ProfileGroup(title: "Sin contacto", iconName: "phone.down.fill")
    static let missingAddress = ProfileGroup(title: "Sin dirección", iconName: "house.fill")
    static let missingEmergency = ProfileGroup(title: "Sin emergencia", iconName: "cross.case.fill")
}

final class DashboardViewController: UIViewController {
    fileprivate struct Metric {
        let title: String
        let value: String
        let iconName: String
        let color: UIColor
    }

    private enum Section: Int, CaseIterable {
        case metrics
        case dynamics
    }

    private var metrics: [Metric] = []
    private var profileGroups: [(group: ProfileGroup, count: Int)] = []
    private var reloadTask: Task<Void, Never>?

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.accessibilityLabel = "Calculando resumen de perfiles"
        return indicator
    }()

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        view.backgroundColor = AppStyle.background
        view.dataSource = self
        view.alwaysBounceVertical = true
        view.register(MetricCollectionViewCell.self, forCellWithReuseIdentifier: MetricCollectionViewCell.reuseIdentifier)
        view.register(DynamicsCollectionViewCell.self, forCellWithReuseIdentifier: DynamicsCollectionViewCell.reuseIdentifier)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.accessibilityIdentifier = "dashboard-collection"
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppStyle.background
        navigationItem.largeTitleDisplayMode = .always
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(profilesDidChange),
            name: PersonalProfileRepository.didChange,
            object: nil
        )
        reloadDashboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDashboard()
    }

    deinit {
        reloadTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func profilesDidChange() {
        reloadDashboard()
    }

    private func reloadDashboard() {
        reloadTask?.cancel()
        loadingIndicator.startAnimating()
        reloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshots = try PersonalProfileRepository.shared.fetchAll().map(\.snapshot)
                let insights = try await ProfileInsightsService.shared.analyze(snapshots)
                try Task.checkCancellation()
                apply(insights)
            } catch is CancellationError {
                return
            } catch {
                loadingIndicator.stopAnimating()
                showError(error, title: "No se pudo actualizar el resumen")
            }
        }
    }

    private func apply(_ insights: ProfileInsights) {
        profileGroups = insights.statusCounts.map { status, count in
            (profileGroup(for: status), count)
        }.sorted { $0.count > $1.count }
        metrics = [
            Metric(title: "Total de perfiles", value: "\(insights.total)", iconName: "person.2.fill", color: AppStyle.accent),
            Metric(title: "Perfiles completos", value: "\(insights.complete)", iconName: "checkmark.seal.fill", color: .systemGreen),
            Metric(title: "Actualizados 7 días", value: "\(insights.recentlyUpdated)", iconName: "clock.arrow.circlepath", color: .systemOrange),
            Metric(title: "Con emergencia", value: "\(insights.withEmergencyContact)", iconName: "cross.case.fill", color: .systemPurple)
        ]
        loadingIndicator.stopAnimating()
        collectionView.reloadData()
    }

    private func profileGroup(for status: ProfileStatus) -> ProfileGroup {
        switch status {
        case .complete: .complete
        case .missingContact: .missingContact
        case .missingAddress: .missingAddress
        case .missingEmergency: .missingEmergency
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let section = Section(rawValue: sectionIndex) else { return nil }
            switch section {
            case .metrics:
                let item = NSCollectionLayoutItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(0.5),
                        heightDimension: .fractionalHeight(1)
                    )
                )
                item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(142)
                    ),
                    repeatingSubitem: item,
                    count: 2
                )
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 6, trailing: 10)
                return layoutSection
            case .dynamics:
                let item = NSCollectionLayoutItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .fractionalHeight(1)
                    )
                )
                item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 18, trailing: 16)
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(360)
                    ),
                    subitems: [item]
                )
                return NSCollectionLayoutSection(group: group)
            }
        }
    }
}

extension DashboardViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Section(rawValue: section) == .metrics ? metrics.count : 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section) {
        case .metrics:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: MetricCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! MetricCollectionViewCell
            cell.configure(with: metrics[indexPath.item])
            return cell
        case .dynamics:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: DynamicsCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! DynamicsCollectionViewCell
            cell.configure(with: profileGroups)
            return cell
        case nil:
            preconditionFailure("Sección de dashboard no válida")
        }
    }
}

private final class MetricCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "MetricCollectionViewCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = AppStyle.cardBackground
        contentView.layer.cornerRadius = 18
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.06
        contentView.layer.shadowRadius = 9
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontForContentSizeCategory = true
        valueLabel.font = .preferredFont(forTextStyle: .title3)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.65

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 30),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no está disponible")
    }

    func configure(with metric: DashboardViewController.Metric) {
        titleLabel.text = metric.title
        valueLabel.text = metric.value
        iconView.image = UIImage(systemName: metric.iconName)
        iconView.tintColor = metric.color
        accessibilityLabel = "\(metric.title), \(metric.value)"
    }
}

private final class DynamicsCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "DynamicsCollectionViewCell"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let resetButton = UIButton(type: .system)
    private let arena = UIView()
    private var animator: UIDynamicAnimator?
    private var bubbles: [UIView] = []
    private var groups: [(group: ProfileGroup, count: Int)] = []
    private var needsDynamicsBuild = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = AppStyle.cardBackground
        contentView.layer.cornerRadius = 20

        titleLabel.text = "Estado de los perfiles"
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Los estados caen, chocan y rebotan usando UIKit Dynamics."
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        resetButton.configuration = .bordered()
        resetButton.configuration?.title = "Reiniciar"
        resetButton.configuration?.image = UIImage(systemName: "arrow.clockwise")
        resetButton.addAction(UIAction { [weak self] _ in self?.restartDynamics() }, for: .touchUpInside)
        resetButton.accessibilityHint = "Vuelve a soltar los estados de los perfiles dentro del área"

        arena.backgroundColor = AppStyle.background
        arena.layer.cornerRadius = 14
        arena.clipsToBounds = true

        [titleLabel, subtitleLabel, resetButton, arena].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: resetButton.leadingAnchor, constant: -10),

            resetButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            resetButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            arena.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            arena.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            arena.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            arena.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no está disponible")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard needsDynamicsBuild, arena.bounds.width > 0, arena.bounds.height > 0 else { return }
        needsDynamicsBuild = false
        buildDynamics()
    }

    func configure(with profileGroups: [(group: ProfileGroup, count: Int)]) {
        groups = profileGroups.isEmpty
            ? [(.complete, 0), (.missingContact, 0), (.missingEmergency, 0)]
            : Array(profileGroups.prefix(6))
        needsDynamicsBuild = true
        setNeedsLayout()
    }

    private func restartDynamics() {
        needsDynamicsBuild = true
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func buildDynamics() {
        animator?.removeAllBehaviors()
        bubbles.forEach { $0.removeFromSuperview() }
        bubbles.removeAll()

        let maximum = groups.map(\.count).max() ?? 0
        let palette: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemTeal]
        let columns = min(3, max(1, groups.count))
        let slotWidth = arena.bounds.width / CGFloat(columns)

        for (index, item) in groups.enumerated() {
            let ratio = maximum > 0 ? Double(item.count) / Double(maximum) : 0.35
            let diameter = 54 + CGFloat(ratio) * 24
            let column = index % columns
            let row = index / columns
            let x = CGFloat(column) * slotWidth + (slotWidth - diameter) / 2
            let y = 6 + CGFloat(row) * 10
            let bubble = makeBubble(group: item.group, count: item.count, color: palette[index % palette.count])
            bubble.frame = CGRect(x: x, y: y, width: diameter, height: diameter)
            bubble.layer.cornerRadius = diameter / 2
            arena.addSubview(bubble)
            bubbles.append(bubble)
        }

        let animator = UIDynamicAnimator(referenceView: arena)
        let gravity = UIGravityBehavior(items: bubbles)
        gravity.magnitude = 0.75

        let collision = UICollisionBehavior(items: bubbles)
        collision.translatesReferenceBoundsIntoBoundary = true

        let properties = UIDynamicItemBehavior(items: bubbles)
        properties.elasticity = 0.68
        properties.friction = 0.18
        properties.resistance = 0.08
        properties.allowsRotation = true

        let push = UIPushBehavior(items: bubbles, mode: .instantaneous)
        push.angle = .pi / 5
        push.magnitude = 0.18

        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(properties)
        animator.addBehavior(push)
        self.animator = animator
    }

    private func makeBubble(group: ProfileGroup, count: Int, color: UIColor) -> UIView {
        let bubble = UIView()
        bubble.backgroundColor = color.withAlphaComponent(0.88)
        bubble.layer.borderWidth = 2
        bubble.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor

        let icon = UIImageView(image: UIImage(systemName: group.iconName))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "\(group.title)\n\(count)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 9, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 18),
            stack.centerXAnchor.constraint(equalTo: bubble.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: bubble.widthAnchor, multiplier: 0.82)
        ])

        bubble.isAccessibilityElement = true
        bubble.accessibilityLabel = "\(group.title), \(count) perfiles"
        return bubble
    }
}
