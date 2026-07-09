import UIKit

final class JarvisHomeViewController: UIViewController {
    private let statusLabel = UILabel()
    private let orbView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.045, blue: 0.05, alpha: 1.0)
        configureOrb()
        configureStatus()
    }

    private func configureOrb() {
        orbView.translatesAutoresizingMaskIntoConstraints = false
        orbView.layer.cornerRadius = 72
        orbView.layer.borderWidth = 1
        orbView.layer.borderColor = UIColor(white: 0.75, alpha: 0.8).cgColor
        view.addSubview(orbView)

        NSLayoutConstraint.activate([
            orbView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            orbView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -70),
            orbView.widthAnchor.constraint(equalToConstant: 144),
            orbView.heightAnchor.constraint(equalToConstant: 144)
        ])
    }

    private func configureStatus() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "JARVIS OFFLINE"
        statusLabel.textColor = UIColor(white: 0.88, alpha: 1.0)
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: orbView.bottomAnchor, constant: 28),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }
}
