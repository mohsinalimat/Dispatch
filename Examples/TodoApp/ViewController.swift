import UIKit
import Render
import Material
import Dispatcher_iOS

class ViewController: UITableViewController {

  let dispatcher: Dispatcher

  init(dispatcher: Dispatcher = Dispatcher.default) {
    self.dispatcher = dispatcher
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    self.dispatcher.appStore.register(observer: self) { _ in
      self.tableView.reloadData()
    }
    super.viewDidLoad()
    self.tableView.estimatedRowHeight = 100
    self.tableView.rowHeight = UITableViewAutomaticDimension
    self.tableView.separatorStyle = .none
    self.tableView.dataSource = self
    self.tableView.reloadData()
  }

}

//MARK: - UITableViewDelegate

extension ViewController {

  override func tableView(_ tableView: UITableView,
                          numberOfRowsInSection section: Int) -> Int {
    let appState = self.dispatcher.appStore.state
    return appState.todoList.count
  }

  override func tableView(_ tableView: UITableView,
                          cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    let id = CellPrototype.defaultIdentifier(TodoComponentView.self)
    let dequeued = tableView.dequeueReusableCell(withIdentifier: id)
    let cell = dequeued ?? ComponentTableViewCell<TodoComponentView>()

    guard let componentCell = cell as? ComponentTableViewCell<TodoComponentView> else {
      return cell
    }

    let appState = self.dispatcher.appStore.state

    componentCell.mountComponentIfNecessary(TodoComponentView())
    componentCell.state = appState.todoList[indexPath.row]
    componentCell.componentView?.delegate = self
    componentCell.render()
    return cell
  }
  
}

//MARK: - Component Delegate

extension ViewController: TodoComponentViewDelegate {

  /** The user finished adding a description for the todo item with the 'id' passed as argument. */
  func didNameTodo(id: String, title: String) {
    self.dispatcher.dispatch(action: Action.name(id: id, title: title))
  }

  /** The user tapped on the check button in the todo item with the 'id' passed as argument */
  func didCheckTodo(id: String) {
    self.dispatcher.dispatch(action: Action.check(id: id))
  }

}
