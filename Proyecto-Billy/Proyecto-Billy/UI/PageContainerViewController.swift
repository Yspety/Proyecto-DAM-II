import UIKit

final class PageContainerViewController: UIViewController {
    private let descriptors = PageDescriptor.mainPages
    private lazy var pages: [UINavigationController] = descriptors.enumerated().map { index, descriptor in
        let content: UIViewController
        if index == 0 {
            content = DashboardViewController()
            content.title = descriptor.title
        } else if index == 1 {
            content = PersonalProfileListViewController()
            content.title = descriptor.title
        } else if index == 2 {
            content = FirebaseSyncViewController()
            content.title = descriptor.title
        } else {
            content = AccountViewController()
            content.title = descriptor.title
        }
        let navigation = UINavigationController(rootViewController: content)
        navigation.navigationBar.prefersLargeTitles = true
        navigation.view.accessibilityIdentifier = "page-\(index)"
        return navigation
    }

    private let pageViewController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )
    private lazy var selector: UISegmentedControl = {
        let control = UISegmentedControl(items: descriptors.map(\.shortTitle))
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(selectorChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.accessibilityLabel = "Secciones de Billy"
        return control
    }()
    private let pageControl: UIPageControl = {
        let control = UIPageControl()
        control.currentPageIndicatorTintColor = AppStyle.accent
        control.pageIndicatorTintColor = .tertiaryLabel
        control.isUserInteractionEnabled = false
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private var currentIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        AppStyle.configureAppearance()
        view.backgroundColor = .systemBackground
        configurePageController()
        configureLayout()
    }

    private func configurePageController() {
        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.setViewControllers([pages[0]], direction: .forward, animated: false)
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
    }

    private func configureLayout() {
        addChild(pageViewController)
        let pageView = pageViewController.view!
        pageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selector)
        view.addSubview(pageView)
        view.addSubview(pageControl)
        pageViewController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            selector.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            selector.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            selector.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            pageView.topAnchor.constraint(equalTo: selector.bottomAnchor, constant: 8),
            pageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -2),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            pageControl.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @objc private func selectorChanged() {
        showPage(at: selector.selectedSegmentIndex, animated: true)
    }

    private func showPage(at index: Int, animated: Bool) {
        guard pages.indices.contains(index), index != currentIndex else { return }
        let direction: UIPageViewController.NavigationDirection = index > currentIndex ? .forward : .reverse
        pageViewController.setViewControllers([pages[index]], direction: direction, animated: animated) { [weak self] completed in
            guard completed else { return }
            self?.updateSelection(to: index)
        }
    }

    private func updateSelection(to index: Int) {
        currentIndex = index
        selector.selectedSegmentIndex = index
        pageControl.currentPage = index
    }
}

extension PageContainerViewController: UIPageViewControllerDataSource {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = pages.firstIndex(where: { $0 === viewController }), index > 0 else { return nil }
        return pages[index - 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = pages.firstIndex(where: { $0 === viewController }), index < pages.count - 1 else { return nil }
        return pages[index + 1]
    }
}

extension PageContainerViewController: UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let visible = pageViewController.viewControllers?.first,
              let index = pages.firstIndex(where: { $0 === visible }) else { return }
        updateSelection(to: index)
    }
}
