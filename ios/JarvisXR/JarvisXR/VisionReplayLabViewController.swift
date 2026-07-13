#if DEBUG
import UIKit

final class VisionReplayLabViewController: UITableViewController {
    private let lab = VisionReplayLab()
    private let scenarios = VisionReplayScenarioKind.allCases
    private var runningScenario: VisionReplayScenarioKind?
    private var summaries: [VisionReplayScenarioKind: String] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Vision Replay Lab"
        view.backgroundColor = JarvisTheme.background
        tableView.backgroundColor = JarvisTheme.background
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ReplayScenario")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Stop",
            style: .plain,
            target: self,
            action: #selector(stopTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityHint = "Stops the active replay and cancels analyzer work."
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        scenarios.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "DEBUG only — production analyzers, synthetic frames"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReplayScenario", for: indexPath)
        let scenario = scenarios[indexPath.row]
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.text = scenario.displayName
        configuration.secondaryText = runningScenario == scenario
            ? "Running through production analyzers…"
            : summaries[scenario] ?? "Double-tap to run"
        configuration.textProperties.color = JarvisTheme.text
        configuration.secondaryTextProperties.color = JarvisTheme.mutedText
        configuration.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
        configuration.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.contentConfiguration = configuration
        cell.backgroundColor = JarvisTheme.panel
        cell.accessibilityLabel = scenario.displayName
        cell.accessibilityValue = configuration.secondaryText
        cell.accessibilityHint = "Runs this prerecorded synthetic sequence through camera quality, inference, tracking, fusion, and narration."
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let kind = scenarios[indexPath.row]
        let route = replayRoute(for: kind)
        runningScenario = kind
        summaries[kind] = nil
        tableView.reloadRows(at: [indexPath], with: .none)
        lab.run(
            scenario: VisionReplayScenarioFactory.make(kind),
            mode: route.mode,
            target: route.target
        ) { [weak self] result in
            guard let self else { return }
            self.runningScenario = nil
            let conditions = result.snapshots.map(\.quality.condition.rawValue)
            let uniqueConditions = NSOrderedSet(array: conditions).array
                .compactMap { $0 as? String }
                .joined(separator: ", ")
            self.summaries[kind] = "\(result.finalStatistics.analyzedFrameCount) total analyzed; " +
                "\(result.narrations.count) narrations; \(result.errors.count) errors; " +
                (uniqueConditions.isEmpty ? "no snapshot" : uniqueConditions)
            self.tableView.reloadData()
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(kind.displayName) replay finished. \(self.summaries[kind] ?? "")"
            )
        }
    }

    private func replayRoute(for scenario: VisionReplayScenarioKind) -> (mode: VisionMode, target: String?) {
        switch scenario {
        case .readablePrintedText, .poorlyFramedText:
            return (.readText, nil)
        case .barcode:
            return (.scanBarcode, nil)
        case .targetEntering, .targetMovingLeftToCenter, .targetLost:
            return (.find, "chair")
        default:
            return (.liveGuide, nil)
        }
    }

    @objc private func stopTapped() {
        lab.stop()
        runningScenario = nil
        tableView.reloadData()
        UIAccessibility.post(notification: .announcement, argument: "Vision replay stopped.")
    }
}
#endif
