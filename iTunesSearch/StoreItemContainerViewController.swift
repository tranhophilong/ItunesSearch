
import UIKit

@MainActor
class StoreItemContainerViewController: UIViewController, UISearchResultsUpdating {
    
    @IBOutlet var tableContainerView: UIView!
    @IBOutlet var collectionContainerView: UIView!
    
    let searchController = UISearchController()
    let storeItemController = StoreItemController()
    
    var tableViewDataSource: StoreItemTableViewDiffableDataSource!
    var collectionViewDataSource: UICollectionViewDiffableDataSource<String, StoreItem.ID>!

    var items = [StoreItem]()
    
    var itemIdentifiersSnapshot = NSDiffableDataSourceSnapshot<String, StoreItem.ID>()

    var selectedSearchScope: SearchScope{
        let selectedIndex = searchController.searchBar.selectedScopeButtonIndex
        let searchScope = SearchScope.allCases[selectedIndex]
        return searchScope
    }
    
    // keep track of async tasks so they can be cancelled if appropriate.
    var searchTask: Task<Void, Never>? = nil
    var tableViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    var collectionViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    
    weak var collectionViewController: StoreItemCollectionViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.automaticallyShowsSearchResultsController = true
        searchController.searchBar.showsScopeBar = true
        searchController.searchBar.scopeButtonTitles = SearchScope.allCases.map({$0.title})
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(fetchMatchingItems), object: nil)
        perform(#selector(fetchMatchingItems), with: nil, afterDelay: 0.3)
    }
                
    @IBAction func switchContainerView(_ sender: UISegmentedControl) {
        tableContainerView.isHidden.toggle()
        collectionContainerView.isHidden.toggle()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tableViewController = segue.destination as? StoreItemListTableViewController {
            configureTableViewDataSource(tableViewController.tableView)
        }
        
        if let collectionViewController = segue.destination as? StoreItemCollectionViewController {
            collectionViewController.configCollectionViewLayout(for: selectedSearchScope)
            configureCollectionViewDataSource(collectionViewController.collectionView)
            self.collectionViewController = collectionViewController
        }
    }

    func configureTableViewDataSource(_ tableView: UITableView) {
        tableViewDataSource = StoreItemTableViewDiffableDataSource(tableView: tableView, cellProvider: { [weak self] tableView, indexPath, itemIdentifier in
            guard let self,
                  let item = items.first(where: { $0.id == itemIdentifier }) else {
                return nil
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "Item", for: indexPath) as! ItemTableViewCell
            
            cell.configure(for: item, storeItemController: storeItemController)
            
            if cell.itemImageView.image == ItemTableViewCell.placeholder {
                tableViewImageLoadTasks[indexPath]?.cancel()
                tableViewImageLoadTasks[indexPath] = Task { [weak self] in
                    guard let self else { return }
                    defer {
                        tableViewImageLoadTasks[indexPath] = nil
                    }
                    do {
                        _ = try await storeItemController.fetchImage(from: item.artworkURL)
                        
                        var snapshot = tableViewDataSource.snapshot()
                        snapshot.reconfigureItems([itemIdentifier])
                        await tableViewDataSource.apply(snapshot, animatingDifferences: true)
                    } catch {
                        print("Error fetching image: \(error)")
                    }
                }
            }
            return cell
        })
    }
    
    func configureCollectionViewDataSource(_ collectionView: UICollectionView) {
        let nib = UINib(nibName: "ItemCollectionViewCell", bundle: Bundle(for: ItemCollectionViewCell.self))
        let cellRegistration = UICollectionView.CellRegistration<ItemCollectionViewCell, StoreItem.ID>(cellNib: nib) { [weak self] cell, indexPath, itemIdentifier in
            guard let self = self,
                  let item = self.items.first(where: { $0.id == itemIdentifier}) else {
                return
            }

            cell.configure(for: item, storeItemController: storeItemController)
            
            if cell.itemImageView.image == ItemCollectionViewCell.placeholder {
                collectionViewImageLoadTasks[indexPath]?.cancel()
                collectionViewImageLoadTasks[indexPath] = Task { [weak self] in
                    guard let self else { return }
                    defer {
                        collectionViewImageLoadTasks[indexPath] = nil
                    }
                    do {
                        _ = try await storeItemController.fetchImage(from: item.artworkURL)
                        
                        var snapshot = collectionViewDataSource.snapshot()
                        snapshot.reconfigureItems([itemIdentifier])
                        await collectionViewDataSource.apply(snapshot, animatingDifferences: true)
                    } catch {
                        print("Error fetching image: \(error)")
                    }
                }
            }
        }
        
        collectionViewDataSource = UICollectionViewDiffableDataSource<String, StoreItem.ID>(collectionView: collectionView) { (collectionView, indexPath, identifier) -> UICollectionViewCell? in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: identifier)
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<StoreItemCollectionViewSectionHeader>(elementKind: "Header") {[weak self] header, elementKind, indexPath in
            
            guard let self else {return}
            
            let title = itemIdentifiersSnapshot.sectionIdentifiers[indexPath.section]
          
            header.setTitle(title)
        }
        
        collectionViewDataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
            
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            
        }
    }
    
    func createSectionedSnapshot(from items: [StoreItem]) -> NSDiffableDataSourceSnapshot<String, StoreItem.ID>{
        let movies = items.filter({$0.kind == "feature_movies"})
        let music = items.filter({$0.kind == "song" || $0.kind == "album"})
        let app = items.filter({$0.kind == "software"})
        let books = items.filter({$0.kind == "ebook"})
        
        let grouped: [(SearchScope, [StoreItem])] = [
            (.apps, app),
            (.books, books),
            (.music, music),
            (.movies, movies)
        ]
        
        var snapshot = NSDiffableDataSourceSnapshot<String, StoreItem.ID>()

        grouped.forEach { (searchScope, storeItems) in
            if storeItems.count > 0{
                snapshot.appendSections([searchScope.title])
                snapshot.appendItems(storeItems.map({$0.id}))
            }
        }
    
        
        return snapshot
       
    }
    
    func handleFetchedItems(_ items: [StoreItem]) async{
        self.items += items
        
        itemIdentifiersSnapshot = createSectionedSnapshot(from: self.items)
        collectionViewController?.configCollectionViewLayout(for: selectedSearchScope)
        
        await self.tableViewDataSource.apply(self.itemIdentifiersSnapshot, animatingDifferences: true)
        await self.collectionViewDataSource.apply(self.itemIdentifiersSnapshot, animatingDifferences: true)
    }
    
    func fetchAndHandleItemsForSearchScopes(_ searchScopes: [SearchScope], withSearchTerm searchTerm: String) async throws {
        try await withThrowingTaskGroup(of: (SearchScope, [StoreItem]).self) { group in
            for searchScope in searchScopes {
                group.addTask {
                    try Task.checkCancellation()
                    
//                    set up query dictionary
                    let query = [
                        "term": searchTerm,
                        "media": searchScope.mediaType,
                        "lang": "en_us",
                        "limit": "30"
                    ]
                    return  (searchScope, try await self.storeItemController.fetchItems(matching: query))
                }
            }
            
            for try await (searchScope, items) in group{
                try Task.checkCancellation()
                if searchTerm == self.searchController.searchBar.text && (self.selectedSearchScope == .all || searchScope == self.selectedSearchScope){
                    await handleFetchedItems(items)
                }
            }
            
        }
    }

    @objc func fetchMatchingItems() {
        
        self.items = []
        itemIdentifiersSnapshot.deleteAllItems()
                
        let searchTerm = searchController.searchBar.text ?? ""
        
        let searchScopes: [SearchScope]
        
        if selectedSearchScope == .all{
            searchScopes = [.apps, .books, .movies, .music]
        }else{
            searchScopes = [selectedSearchScope]
        }
        
        // cancel any images that are still being fetched and reset the imageTask dictionaries
        collectionViewImageLoadTasks.values.forEach { task in task.cancel() }
        collectionViewImageLoadTasks = [:]
        tableViewImageLoadTasks.values.forEach { task in task.cancel() }
        tableViewImageLoadTasks = [:]
        
        // cancel existing task since we will not use the result
        searchTask?.cancel()
        searchTask = Task {
            if !searchTerm.isEmpty {
                
                // set up query dictionary
               
            
                do {
                    try await fetchAndHandleItemsForSearchScopes(searchScopes, withSearchTerm: searchTerm)
                    
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // ignore cancellation errors
                } catch {
                    // otherwise, print an error to the console
                    print(error)
                }
 
            } else {
                await self.tableViewDataSource.apply(self.itemIdentifiersSnapshot, animatingDifferences: true)
                await self.collectionViewDataSource.apply(self.itemIdentifiersSnapshot, animatingDifferences: true)
            }
            searchTask = nil
        }
    }
}
