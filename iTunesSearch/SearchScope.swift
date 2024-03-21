//
//  SearchScope.swift
//  iTunesSearch
//
//  Created by Long Tran on 18/03/2024.
//

import UIKit


enum SearchScope: CaseIterable{
    case all, movies, music, apps, books
    
    var title: String{
        switch self{
        case .all:
            return "All"
        case .movies:
            return "Movies"
        case .music:
            return "Music"
        case .apps:
            return "Apps"
        case .books:
            return "Books"
        }
        
    }
    
    var mediaType: String{
        switch self{
        case .all:
            return "all"
        case .movies:
            return "movie"
        case .music:
            return "music"
        case .apps:
            return "software"
        case .books:
            return "ebook"
        }
    }
}


extension SearchScope{
    var orthogonalScrollingBehavior: UICollectionLayoutSectionOrthogonalScrollingBehavior{
        switch self{
        case .all: .continuousGroupLeadingBoundary
        default: .none
        }
    }
    
    var groupItemCount: Int{
        switch self{
        case .all: 1
        default: 3
        }
    }
    
    var groupWidthDimension: NSCollectionLayoutDimension{
        switch self{
        case .all: .fractionalWidth(1/3)
        default: .fractionalWidth(1)
        }
    }
}
