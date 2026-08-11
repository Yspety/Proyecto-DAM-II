import UIKit

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
    private var categoryTotals: [(category: ExpenseCategory, total: Double)] = []

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
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(expensesDidChange),
            name: ExpenseRepository.didChange,
            object: nil
        )
        reloadDashboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDashboard()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func expensesDidChange() {
        reloadDashboard()
    }

    private func reloadDashboard() {
        do {
            let expenses = try ExpenseRepository.shared.fetchAll()
            let total = expenses.reduce(0) { $0 + $1.amount }
            let monthlyExpenses = expenses.filter {
                Calendar.current.isDate($0.date ?? .distantPast, equalTo: Date(), toGranularity: .month)
            }
            let monthlyTotal = monthlyExpenses.reduce(0) { $0 + $1.amount }

            let grouped = Dictionary(grouping: expenses) {
                ExpenseCategory(rawValue: $0.safeCategory) ?? .other
            }
            categoryTotals = grouped.map { category, values in
                (category, values.reduce(0) { $0 + $1.amount })
            }.sorted { $0.total > $1.total }

            let topCategory = categoryTotals.first?.category.rawValue ?? "Sin datos"
            metrics = [
                Metric(title: "Gasto total", value: currency(total), iconName: "wallet.bifold.fill", color: AppStyle.accent),
                Metric(title: "Este mes", value: currency(monthlyTotal), iconName: "calendar", color: .systemGreen),
                Metric(title: "Movimientos", value: "\(expenses.count)", iconName: "list.number", color: .systemOrange),
                Metric(title: "Categoría principal", value: topCategory, iconName: "tag.fill", color: .systemPurple)
            ]
            collectionView.reloadData()
        } catch {
            showError(error, title: "No se pudo actualizar el resumen")
        }
    }

    private func currency(_ value: Double) -> String {
        NumberFormatter.penCurrency.string(from: value as NSNumber) ?? String(format: "S/ %.2f", value)
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
            cell.configure(with: categoryTotals)
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
    private var totals: [(category: ExpenseCategory, total: Double)] = []
    private var needsDynamicsBuild = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = AppStyle.cardBackground
        contentView.layer.cornerRadius = 20

        titleLabel.text = "Gastos en movimiento"
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Las categorías caen, chocan y rebotan usando UIKit Dynamics."
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        resetButton.configuration = .bordered()
        resetButton.configuration?.title = "Reiniciar"
        resetButton.configuration?.image = UIImage(systemName: "arrow.clockwise")
        resetButton.addAction(UIAction { [weak self] _ in self?.restartDynamics() }, for: .touchUpInside)
        resetButton.accessibilityHint = "Vuelve a soltar las categorías dentro del área"

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

    func configure(with categoryTotals: [(category: ExpenseCategory, total: Double)]) {
        totals = categoryTotals.isEmpty
            ? [(.food, 0), (.transport, 0), (.other, 0)]
            : Array(categoryTotals.prefix(6))
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

        let maximum = totals.map(\.total).max() ?? 0
        let palette: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemTeal]
        let columns = min(3, max(1, totals.count))
        let slotWidth = arena.bounds.width / CGFloat(columns)

        for (index, item) in totals.enumerated() {
            let ratio = maximum > 0 ? item.total / maximum : 0.35
            let diameter = 54 + CGFloat(ratio) * 24
            let column = index % columns
            let row = index / columns
            let x = CGFloat(column) * slotWidth + (slotWidth - diameter) / 2
            let y = 6 + CGFloat(row) * 10
            let bubble = makeBubble(category: item.category, total: item.total, color: palette[index % palette.count])
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

    private func makeBubble(category: ExpenseCategory, total: Double, color: UIColor) -> UIView {
        let bubble = UIView()
        bubble.backgroundColor = color.withAlphaComponent(0.88)
        bubble.layer.borderWidth = 2
        bubble.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor

        let icon = UIImageView(image: UIImage(systemName: category.iconName))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = total > 0 ? "\(category.rawValue)\n\(compactCurrency(total))" : category.rawValue
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
        bubble.accessibilityLabel = total > 0
            ? "\(category.rawValue), \(NumberFormatter.penCurrency.string(from: total as NSNumber) ?? "")"
            : category.rawValue
        return bubble
    }

    private func compactCurrency(_ value: Double) -> String {
        if value >= 1_000 {
            return String(format: "S/ %.1fk", value / 1_000)
        }
        return String(format: "S/ %.0f", value)
    }
}
