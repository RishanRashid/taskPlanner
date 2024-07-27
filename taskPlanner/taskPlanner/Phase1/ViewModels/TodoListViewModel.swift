//
//  TodoListViewModel.swift
//  taskPlanner
//
//  Created by Allnet Systems on 7/2/24.
//

import Foundation
import RxSwift
import RxCocoa

enum Section: String {
    case scheduled = "Scheduled"
    case anytime = "Anytime"
}

enum DefaultsKey {
    static let isFirstLaunch = "isFirstLaunch"
}

enum TabBarItem: String {
    case allTasks = "All Tasks"
    case completed = "Completed"
}

class TodoListViewModel: NSObject {
    var todoScheduled = BehaviorRelay<[String: [Todo]]>(value: [:])
    var todoAnytime = BehaviorRelay<[Todo]>(value: [])
    var completedScheduled = BehaviorRelay<[String: [Todo]]>(value: [:])
    var completedAnytime = BehaviorRelay<[Todo]>(value: [])
    var selectedDate = BehaviorRelay<Date>(value: Date())
    
    var disposeBag = DisposeBag()
    
    override init() {
        super.init()
        
        if UserDefaults.standard.value(forKey: DefaultsKey.isFirstLaunch) != nil {
            loadAllData()
        } else {
            loadFirstData()
        }
        
        todoScheduled
            .subscribe(onNext: { [weak self] in
                self?.saveData(data: $0, key: Section.scheduled.rawValue)
            })
            .disposed(by: disposeBag)
        
        todoAnytime
            .subscribe(onNext: { [weak self] in
                self?.saveData(data: $0, key: Section.anytime.rawValue)
            })
            .disposed(by: disposeBag)
        
        completedScheduled
            .subscribe(onNext: { [weak self] in
                self?.saveData(data: $0, key: "Completed" + Section.scheduled.rawValue)
            })
            .disposed(by: disposeBag)
        
        completedAnytime
            .subscribe(onNext: { [weak self] in
                self?.saveData(data: $0, key: "Completed" + Section.anytime.rawValue)
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Data Processing
    
    func saveData<T: Encodable>(data: T, key: String) {
        let userDefaults = UserDefaults.standard
        let encoder = JSONEncoder()
        
        if let jsonData = try? encoder.encode(data) {
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                userDefaults.set(jsonString, forKey: key)
            }
        }
        
        userDefaults.synchronize()
    }
    
    func loadAllData() {
        let userDefaults = UserDefaults.standard
        let decoder = JSONDecoder()
        
        // Scheduled
        if let jsonString = userDefaults.value(forKey: Section.scheduled.rawValue) as? String {
            if let jsonData = jsonString.data(using: .utf8),
               let scheduledData = try? decoder.decode([String: [Todo]].self, from: jsonData) {
                todoScheduled.accept(scheduledData)
            }
        }
        
        if let jsonString = userDefaults.value(forKey: Section.anytime.rawValue) as? String {
            if let jsonData = jsonString.data(using: .utf8),
               let anytimeData = try? decoder.decode([Todo].self, from: jsonData) {
                todoAnytime.accept(anytimeData)
            }
        }
        
        if let jsonString = userDefaults.value(forKey: "Completed" + Section.scheduled.rawValue) as? String {
            if let jsonData = jsonString.data(using: .utf8),
               let completedData = try? decoder.decode([String: [Todo]].self, from: jsonData) {
                completedScheduled.accept(completedData)
            }
        }
        
        if let jsonString = userDefaults.value(forKey: "Completed" + Section.anytime.rawValue) as? String {
            if let jsonData = jsonString.data(using: .utf8),
               let completedData = try? decoder.decode([Todo].self, from: jsonData) {
                completedAnytime.accept(completedData)
            }
        }
    }
    
    func loadFirstData() {
        let userDefaults = UserDefaults.standard
        let date = selectedDate.value.toString()
        
        userDefaults.setValue(false, forKey: DefaultsKey.isFirstLaunch)
        self.todoScheduled.accept([date: [Todo(title: "Create new task",
                                                date: date,
                                                time: "8:00 PM",
                                                description: "Add Some Future task notes")]])
        self.todoAnytime.accept([Todo(title: "Update your task", date: "", time: "", description: "This task has not yet been scheduled.")])
        userDefaults.synchronize()
    }
    
    // MARK: - Tasks
    
    func changeComplete(tabBarItem: TabBarItem, row: Int) {
        if tabBarItem == .allTasks {
            var tasks = todoScheduled.value
            let date = selectedDate.value.toString()
            
            // Toggle the completion status of the task
            if var dailyTasks = tasks[date] {
                dailyTasks[row].isCompleted.toggle()
                
                // Move task to completed if it is completed
                if dailyTasks[row].isCompleted {
                    var completedTasks = completedScheduled.value
                    let task = dailyTasks.remove(at: row)
                    completedTasks[date, default: []].append(task)
                    completedScheduled.accept(completedTasks)
                } else {
                    // Move task back to scheduled if it is not completed
                    var completedTasks = completedScheduled.value
                    if let taskIndex = completedTasks[date]?.firstIndex(where: { $0.id == dailyTasks[row].id }) {
                        let task = completedTasks[date]?.remove(at: taskIndex)
                        if let task = task {
                            dailyTasks.append(task)
                            completedScheduled.accept(completedTasks)
                        }
                    }
                }
                
                tasks[date] = dailyTasks
                todoScheduled.accept(tasks)
            }
        } else if tabBarItem == .completed {
            var tasks = todoAnytime.value
                tasks[row].isCompleted.toggle()
            
            if tasks[row].isCompleted {
                var completedTasks = completedAnytime.value
                let task = tasks.remove(at: row)
                completedTasks.append(task)
                completedAnytime.accept(completedTasks)
            } else {
                var completedTasks = completedAnytime.value
                if let taskIndex = completedTasks.firstIndex(where: { $0.id == tasks[row].id }) {
                    let task = completedTasks.remove(at: taskIndex)
                    tasks.append(task)
                    completedAnytime.accept(completedTasks)
                }
            }
            
            todoAnytime.accept(tasks)
        }
    }

    
    func insert(task: Todo, section: Section, row: Int?, date: String?) {
        var task = task
        
        if section == .scheduled {
            var scheduled = todoScheduled.value
            let date = date ?? selectedDate.value.toString()
            var newTasks = todoScheduled.value[date] ?? []
            
            task.date = date
            if let row = row { newTasks.insert(task, at: row) }
            else { newTasks.append(task) }
            
            scheduled[date] = newTasks
            todoScheduled.accept(scheduled)
        } else if section == .anytime {
            var anytime = todoAnytime.value
            
            task.date = ""
            task.time = ""
            if let row = row { anytime.insert(task, at: row) }
            else { anytime.append(task) }
            
            todoAnytime.accept(anytime)
        }
    }
    
    func remove(section: Section, row: Int, date: String?) -> Todo? {
        var removedTask: Todo?
        
        if section == .scheduled {
            var scheduled = todoScheduled.value
            let date = date ?? selectedDate.value.toString()
            
            removedTask = scheduled[date]?.remove(at: row)
            todoScheduled.accept(scheduled)
        } else if section == .anytime {
            var anytime = todoAnytime.value
            
            removedTask = anytime.remove(at: row)
            todoAnytime.accept(anytime)
        }
        
        return removedTask
    }
}
