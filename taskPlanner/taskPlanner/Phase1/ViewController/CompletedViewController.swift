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

class CompletedViewController: UIViewController {
    
    @IBOutlet weak var tblCompletedTasks: UITableView!
        
        private var completedTaskSections: BehaviorRelay<[Task]> = BehaviorRelay(value: [])
        private var dataSource: RxTableViewSectionedReloadDataSource<Task>!
        var viewModel = CompletedTasksViewModel()
        var disposeBag = DisposeBag()
        
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            let nibName = UINib(nibName: TodoTableViewCell.nibName, bundle: nil)
            tblCompletedTasks.register(nibName, forCellReuseIdentifier: TodoTableViewCell.identifier)
            tblCompletedTasks.rowHeight = UITableView.automaticDimension
            setupBindings()
        }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            tblCompletedTasks.reloadData()
        }
        
        // MARK: - UI Binding
        
        func setupBindings() {
            dataSource = RxTableViewSectionedReloadDataSource<Task> { dataSource, tableView, indexPath, item in
                let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as! TodoTableViewCell
                cell.bind(task: item)
                return cell
            }
            
            completedTaskSections.asDriver()
                .drive(tblCompletedTasks.rx.items(dataSource: dataSource))
                .disposed(by: disposeBag)
            
            viewModel.completedTasks
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] tasks in
                    self?.completedTaskSections.accept([Task(date: "", items: tasks)])
                })
                .disposed(by: disposeBag)
            
            tblCompletedTasks.rx.modelSelected(Todo.self)
                .subscribe(onNext: { [weak self] todo in
                    print("Selected task: \(todo)")
                })
                .disposed(by: disposeBag)
        }
    }
