//
//  DailyTasksViewController.swift
//  taskPlanner
//
//  Created by Allnet Systems on 7/2/24.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import CoreLocation

protocol SendDataDelegate {
    func sendData(oldTask: Todo?, newTask: Todo, indexPath: IndexPath?)
    func sendData(scheduledTasks: [String: [Todo]], newDate: Date)
}

class DailyTasksViewController: UIViewController {
    
    @IBOutlet weak var tblTodo: UITableView!
    @IBOutlet weak var btnAdd: UIButton!
    @IBOutlet weak var btnEditTable: UIBarButtonItem!
    @IBOutlet weak var cityname: UILabel!
    @IBOutlet weak var weatherLabel: UILabel!
    @IBOutlet weak var weatherImage: UIImageView!
    
    private var todoSections: BehaviorRelay<[Task]> = BehaviorRelay(value: [])
    private var dataSource: RxTableViewSectionedReloadDataSource<Task>!
    var viewModel = TodoListViewModel()
    var disposeBag = DisposeBag()
    var weatherManager = WeatherManager()
    let locationManager = CLLocationManager()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWeather()
        setupBindings()
        setupTable()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tblTodo.reloadData()
    }
    func setupWeather() {
        locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
            weatherManager.delegate = self
    }
    
    func setupTable() {
        let nibName = UINib(nibName: TodoTableViewCell.nibName, bundle: nil)
        tblTodo.register(nibName, forCellReuseIdentifier: TodoTableViewCell.identifier)
        tblTodo.rowHeight = UITableView.automaticDimension
    }
    
    func setupBindings() {
        dataSource = RxTableViewSectionedReloadDataSource<Task> { dataSource, tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as! TodoTableViewCell
            
            cell.bind(task: item)
            
            cell.btnCheckbox.indexPath = indexPath
            cell.btnCheckbox.addTarget(self, action: #selector(self.checkboxSelection(_:)), for: .touchUpInside)
            return cell
        }
        
        Observable.zip(tblTodo.rx.modelSelected(Todo.self), tblTodo.rx.itemSelected)
            .bind { [weak self] (task, indexPath) in
                guard let addTaskVC = self?.storyboard?.instantiateViewController(identifier: AddTaskViewController.storyboardID) as? AddTaskViewController else { return }
                addTaskVC.editTask = task
                addTaskVC.indexPath = indexPath
                addTaskVC.delegate = self
                addTaskVC.currentDate = self?.viewModel.selectedDate.value
                
                self?.navigationController?.pushViewController(addTaskVC, animated: true)
            }
            .disposed(by: disposeBag)
        
        tblTodo.rx.itemDeleted
            .bind { indexPath in
                if indexPath.section == 0 {
                    _ = self.viewModel.remove(section: .scheduled, row: indexPath.row, date: nil)
                } else {
                    _ = self.viewModel.remove(section: .anytime, row: indexPath.row, date: nil)
                }
            }
            .disposed(by: disposeBag)
        
        tblTodo.rx.itemMoved
            .bind { srcIndexPath, dstIndexPath in
                var movedTask: Todo?
                
                if srcIndexPath.section == 0 {
                    movedTask = self.viewModel.remove(section: .scheduled, row: srcIndexPath.row, date: nil)
                } else {
                    movedTask = self.viewModel.remove(section: .anytime, row: srcIndexPath.row, date: nil)
                }
                
                if let movedTask = movedTask {
                    if dstIndexPath.section == 0 {
                        self.viewModel.insert(task: movedTask, section: .scheduled, row: dstIndexPath.row, date: nil)
                    } else {
                        self.viewModel.insert(task: movedTask, section: .anytime, row: dstIndexPath.row, date: nil)
                    }
                }
            }
            .disposed(by: disposeBag)
        
        dataSource.titleForHeaderInSection = { ds, index in
            let date = ds.sectionModels[index].date
            return date.isEmpty ? Section.anytime.rawValue : "\(Section.scheduled.rawValue) \(date)"
        }
        
        todoSections.asDriver()
            .drive(tblTodo.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        Observable.combineLatest(viewModel.todoScheduled, viewModel.todoAnytime, viewModel.selectedDate)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] scheduled, anytime, date in
                let dateString = date.toString()
                self?.todoSections.accept([Task(date: dateString, items: scheduled[dateString] ?? []),
                                           Task(date: "", items: anytime)])
            })
            .disposed(by: disposeBag)
    }
    
    @IBAction func addTaskButtonPressed(_ sender: UIButton) {
        guard let addTaskVC = self.storyboard?.instantiateViewController(identifier: AddTaskViewController.storyboardID) as? AddTaskViewController else { return }
        addTaskVC.delegate = self
        addTaskVC.currentDate = viewModel.selectedDate.value
        
        self.navigationController?.pushViewController(addTaskVC, animated: true)
    }
    
    @IBAction func editTableButtonPressed(_ sender: UIBarButtonItem) {
        if tblTodo.isEditing {
            btnEditTable.title = "Edit"
            tblTodo.setEditing(false, animated: true)
        } else {
            btnEditTable.title = "Done"
            tblTodo.setEditing(true, animated: true)
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
    
    @objc func checkboxSelection(_ sender: CheckUIButton) {
        guard let indexPath = sender.indexPath else { return }
        
        if indexPath.section == 0 {
            viewModel.changeComplete(tabBarItem: .allTasks, row: indexPath.row)
        } else {
            viewModel.changeComplete(tabBarItem: .completed, row: indexPath.row)
        }
    }
}


extension DailyTasksViewController: SendDataDelegate {
    
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
}


extension DailyTasksViewController: CLLocationManagerDelegate, WeatherManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            weatherManager.fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }
    func didUpdateWeather(_ weatherManager: WeatherManager, weather: WeatherModel) {
        DispatchQueue.main.async {
            self.locationManager.stopUpdatingLocation()
            self.weatherLabel.text = weather.tempratureString
            self.weatherImage.image = UIImage(systemName: weather.conditionName)
            self.cityname.text = weather.name
        }
    }

    func didFailWithError(error: Error) {
        print("Failed to fetch weather: \(error.localizedDescription)")
    }

    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("Location access denied. Please enable location services for this app in Settings.")
            case .locationUnknown:
                print("Location data is currently unavailable.")
            case .network:
                print("Network error occurred while retrieving location.")
            default:
                print("An error occurred: \(error.localizedDescription)")
            }
        } else {
            print("Failed to find user's location: \(error.localizedDescription)")
        }
    }

}



