//
//  StoreItemTableViewDiffableDataSource.swift
//  iTunesSearch
//
//  Created by Long Tran on 18/03/2024.
//

import UIKit


@MainActor
class StoreItemTableViewDiffableDataSource: UITableViewDiffableDataSource<String, StoreItem.ID>{
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return snapshot().sectionIdentifiers[section]
    }
}
