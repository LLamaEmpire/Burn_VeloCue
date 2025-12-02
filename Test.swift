import UIKit

class TestViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a label to display "Hello"
        let label = UILabel()
        label.text = "Hello"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the label to the view hierarchy
        view.addSubview(label)
        
        // Center the label in the view using Auto Layout
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}