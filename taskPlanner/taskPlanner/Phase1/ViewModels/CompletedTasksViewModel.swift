//
//  CompletedTasksViewModel.swift
//  taskPlanner
//
//  Created by Allnet Systems on 7/26/24.
//

import Foundation
import RxSwift
import RxCocoa

class CompletedTasksViewModel {
    var completedTasks = BehaviorRelay<[Todo]>(value: [])
    var disposeBag = DisposeBag()
    
    init() {
        loadCompletedTasks()
    }
    
    private func loadCompletedTasks() {
        let scheduledTasks = loadScheduledTasks()
        let anytimeTasks = loadAnytimeTasks()
        
        let completedScheduledTasks = scheduledTasks.values.flatMap { $0 }.filter { $0.isCompleted }
        let completedAnytimeTasks = anytimeTasks.filter { $0.isCompleted }
        
        let allCompletedTasks = completedScheduledTasks + completedAnytimeTasks
        completedTasks.accept(allCompletedTasks)
    }
    
    private func loadScheduledTasks() -> [String: [Todo]] {
        let userDefaults = UserDefaults.standard
        let decoder = JSONDecoder()
        
        if let jsonString = userDefaults.value(forKey: Section.scheduled.rawValue) as? String {
            if let jsonData = jsonString.data(using: .utf8),
               let scheduledData = try? decoder.decode([String : [Todo]].self, from: jsonData) {
                return scheduledData
            }
        }
        
        return [:]
    }
    
    private func loadAnytimeTasks() -> [Todo] {
        let userDefaults = UserDefaults.standard
        let decoder = JSONDecoder()
        
        if let jsonString = userDefaults.value(forKey: Section.anytime.rawValue) as? String {
            if let jsonData = jsonString.data(using: .utf8),
               let anytimeData = try? decoder.decode([Todo].self, from: jsonData) {
                return anytimeData
            }
        }
        
        return []
    }
}
