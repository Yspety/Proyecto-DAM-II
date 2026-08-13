import UIKit

final class CountrySearchViewController: UITableViewController, UISearchResultsUpdating {
    var onSelection: ((Country) -> Void)?

    private let searchController = UISearchController(searchResultsController: nil)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private var countries: [Country] = []
    private var searchTask: Task<Void, Never>?

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) no está disponible") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Buscar país"
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Ej. Perú"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CountryCell")
        tableView.backgroundView = makeMessage("Escribe al menos dos letras para consultar el servicio REST.")
        loadingIndicator.hidesWhenStopped = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: loadingIndicator)
    }

    deinit { searchTask?.cancel() }

    func updateSearchResults(for searchController: UISearchController) {
        searchTask?.cancel()
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard query.count >= 2 else {
            countries = []
            tableView.reloadData()
            tableView.backgroundView = makeMessage("Escribe al menos dos letras para consultar el servicio REST.")
            loadingIndicator.stopAnimating()
            return
        }

        loadingIndicator.startAnimating()
        tableView.backgroundView = nil
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                let results = try await CountryAPIClient.shared.searchCountries(named: query)
                try Task.checkCancellation()
                guard let self else { return }
                countries = results
                loadingIndicator.stopAnimating()
                tableView.backgroundView = results.isEmpty ? makeMessage("No se encontraron resultados.") : nil
                tableView.reloadData()
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                countries = []
                loadingIndicator.stopAnimating()
                tableView.backgroundView = makeMessage(error.localizedDescription)
                tableView.reloadData()
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { countries.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let country = countries[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "CountryCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = country.displayName
        content.secondaryText = [country.capital?.first, country.region, country.cca2]
            .compactMap { $0 }
            .joined(separator: " · ")
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelection?(countries[indexPath.row])
        navigationController?.popViewController(animated: true)
    }

    private func makeMessage(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }
}
