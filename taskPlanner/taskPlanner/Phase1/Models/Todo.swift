//
//  Todo.swift
//  taskPlanner
//
//  Created by Allnet Systems on 7/2/24.
//

import Foundation

struct Todo: Codable {
    var id: UUID
    var title: String
    var date: String?
    var time: String?
    var description: String?
    var isCompleted: Bool = false
    
    init(title: String, date: String? = nil, time: String? = nil, description: String? = nil, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.time = time
        self.description = description
        self.isCompleted = isCompleted
    }
}

extension Todo: Equatable {
    static let empty = Todo(title: "", date: "", time: "", description: "")
    
    static func == (lhs: Todo, rhs: Todo) -> Bool {
        return lhs.id == rhs.id
    }
}
