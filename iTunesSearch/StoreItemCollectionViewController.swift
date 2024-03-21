
import UIKit

class StoreItemCollectionViewController: UICollectionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    
    func configCollectionViewLayout(for searchScope: SearchScope){
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: searchScope.groupWidthDimension, heightDimension: .absolute(166))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: searchScope.groupItemCount)
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = searchScope.orthogonalScrollingBehavior
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
        let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: "Header", alignment: .topLeading)
        
        section.boundarySupplementaryItems = [headerItem]
        
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout(section: section)
    }
}
