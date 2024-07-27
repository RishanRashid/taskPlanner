//
//  CompletedViewController.swift
//  taskPlanner
//
//  Created by Allnet Systems on 7/26/24.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

class CompletedViewController: UIViewController, SendDataDelegate {

    func sendData(scheduledTasks: [String: [Todo]], newDate: Date) {
        if !scheduledTasks.isEmpty {
            viewModel.todoScheduled.accept(scheduledTasks)
        }
        viewModel.selectedDate.accept(newDate)
    }
    
    func sendData(oldTask: Todo?, newTask: Todo, indexPath: IndexPath?) {
        let oldDate = oldTask?.date ?? ""
        let newDate = newTask.date ?? ""
        
        if let _ = oldTask, let index = indexPath {
            if oldDate.isEmpty {
                _ = viewModel.remove(section: .anytime, row: index.row, date: nil)
                _ = viewModel.remove(section: .scheduled, row: index.row, date: oldTask?.date)
            }
        }
        
        if newDate.isEmpty {
            viewModel.insert(task: newTask, section: .anytime, row: indexPath?.row, date: nil)
        } else {
            viewModel.insert(task: newTask, section: .scheduled, row: indexPath?.row, date: newDate)
        }
    }
    
    @IBOutlet weak var tblCompletedTasks: UITableView!
    
    private var completedTasks: BehaviorRelay<[Task]> = BehaviorRelay(value: [])
    private var dataSource: RxTableViewSectionedReloadDataSource<Task>!
    var viewModel = TodoListViewModel()
    var disposeBag = DisposeBag()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTable()
        setupBindings()
    }
    
    func setupTable() {
        let nibName = UINib(nibName: TodoTableViewCell.nibName, bundle: nil)
        tblCompletedTasks.register(nibName, forCellReuseIdentifier: TodoTableViewCell.identifier)
        tblCompletedTasks.rowHeight = UITableView.automaticDimension
    }

    @IBAction func backButton(_ sender: UIBarButtonItem) {
        if let tabBarController = self.tabBarController {
            tabBarController.selectedIndex = 0
        }
    }

    @IBAction func calendarButtonPressed(_ sender: UIBarButtonItem) {
        guard let calendarVC = self.storyboard?.instantiateViewController(identifier: CalendarViewController.storyboardID) as? CalendarViewController else { return }
        calendarVC.delegate = self
        calendarVC.todoScheduled = viewModel.todoScheduled.value
        calendarVC.selectedDate = viewModel.selectedDate.value
        
        let navController = UINavigationController(rootViewController: calendarVC)
        navController.modalPresentationStyle = .fullScreen
        
        present(navController, animated: true, completion: nil)
    }

    func setupBindings() {
        dataSource = RxTableViewSectionedReloadDataSource<Task> { dataSource, tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as! TodoTableViewCell
            cell.bind(task: item)
            return cell
        }
        
        Observable.combineLatest(viewModel.todoScheduled, viewModel.todoAnytime)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] scheduled, anytime in
                let completedScheduled = scheduled.values.flatMap { $0 }.filter { $0.isCompleted }
                let completedAnytime = anytime.filter { $0.isCompleted }
                
                let tasks = [Task(date: "Scheduled", items: completedScheduled),
                             Task(date: "Anytime", items: completedAnytime)]
                
                if tasks.flatMap({ $0.items }).isEmpty {
                    self?.showNoCompletedTasksAlert()
                }
                
                self?.completedTasks.accept(tasks)
            })
            .disposed(by: disposeBag)
        
        completedTasks.asDriver()
            .drive(tblCompletedTasks.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }

    private func showNoCompletedTasksAlert() {
        let alert = UIAlertController(title: "No Completed Tasks", message: "There are no completed tasks available.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
