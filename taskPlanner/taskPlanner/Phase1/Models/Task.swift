//
//  Task.swift
//  taskPlanner
//
//  Created by Allnet Systems on 7/2/24.
//

import Foundation
import RxDataSources

struct Task {
    var date: String
    var items: [Todo]
}

extension Task: SectionModelType {
    typealias Item = Todo
    
    init(original: Task, items: [Item]) {
        self = original
        self.items = items
    }
}
