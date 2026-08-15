import UIKit

final class PageContainerViewController: UIViewController {
    @IBOutlet private weak var selector: UISegmentedControl!
    @IBOutlet private weak var pageControl: UIPageControl!
    @IBOutlet private weak var privacyOverlay: UIView!
    @IBOutlet private weak var unlockButton: UIButton!

    private var pageViewController: UIPageViewController!
    private var unlockTask: Task<Void, Never>?
    private var requiresUnlock = true
    private let descriptors = PageDescriptor.mainPages
    private lazy var pages: [UINavigationController] = {
        let identifiers = ["dashboardNavigation", "profilesNavigation", "servicesNavigation", "accountNavigation"]
        return identifiers.map { identifier in
            guard let navigation = storyboard?.instantiateViewController(withIdentifier: identifier) as? UINavigationController else {
                preconditionFailure("No se encontró la navegación \(identifier) en Main.storyboard")
            }
            navigation.navigationBar.prefersLargeTitles = true
            return navigation
        }
    }()

    private var currentIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        AppStyle.configureAppearance()
        view.backgroundColor = .systemBackground
        configureStoryboardViews()
        configurePageController()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(requireAuthentication),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if requiresUnlock { authenticate() }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "embedPages", let controller = segue.destination as? UIPageViewController {
            pageViewController = controller
        }
    }

    deinit { unlockTask?.cancel() }

    private func configureStoryboardViews() {
        selector.removeAllSegments()
        for (index, descriptor) in descriptors.enumerated() {
            selector.insertSegment(withTitle: descriptor.shortTitle, at: index, animated: false)
        }
        selector.selectedSegmentIndex = 0
        selector.accessibilityLabel = "Secciones de Billy"

        pageControl.numberOfPages = descriptors.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = AppStyle.accent
        pageControl.pageIndicatorTintColor = .tertiaryLabel

        privacyOverlay.backgroundColor = AppStyle.background
        unlockButton.setTitle("Desbloquear con \(BiometricAuthService.shared.biometricName())", for: .normal)
    }

    @IBAction private func selectorChanged(_ sender: UISegmentedControl) {
        showPage(at: sender.selectedSegmentIndex, animated: true)
    }

    @IBAction private func unlockTapped(_ sender: UIButton) {
        authenticate()
    }

    @objc private func requireAuthentication() {
        requiresUnlock = true
        privacyOverlay.isHidden = false
        view.bringSubviewToFront(privacyOverlay)
    }

    private func authenticate() {
        unlockTask?.cancel()
        unlockButton.isEnabled = false
        unlockTask = Task { [weak self] in
            guard let self else { return }
            let result = await BiometricAuthService.shared.authenticate(
                reason: "Desbloquea el acceso a tus perfiles personales."
            )
            unlockButton.isEnabled = true
            switch result {
            case .authenticated:
                requiresUnlock = false
                privacyOverlay.isHidden = true
            case .unavailable(let message):
                requiresUnlock = false
                privacyOverlay.isHidden = true
                showBiometricMessage(message)
            case .failed(let message):
                showBiometricMessage(message)
            }
        }
    }

    private func showBiometricMessage(_ message: String) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Protección biométrica", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    private func configurePageController() {
        guard pageViewController != nil else {
            preconditionFailure("Main.storyboard no conectó el contenedor UIPageViewController")
        }
        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.setViewControllers([pages[0]], direction: .forward, animated: false)
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
