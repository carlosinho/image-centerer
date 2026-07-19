import AppKit
import Foundation
import ImageCentererCore

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/carlosinho/image-centerer/releases/latest")!
    private static let repositoryURL = URL(string: "https://github.com/carlosinho/image-centerer")!
    private static let lastCheckDefaultsKey = "lastUpdateCheckDate"
    private static let updateInstructions = "Update by pulling the repository and re-running scripts/package-app.sh."

    private var checkTask: Task<Void, Never>?

    private struct LatestRelease: Decodable {
        let tagName: String
        let htmlURL: URL?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    func checkNow() {
        check(silently: false)
    }

    func checkOnLaunchIfDue() {
        // Builds run through `swift run` have no bundle version; skip the scheduled check.
        guard currentVersion != nil else { return }
        let lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckDefaultsKey) as? Date
        guard UpdateCheckSchedule.isCheckDue(lastCheck: lastCheck) else { return }
        check(silently: true)
    }

    private func check(silently: Bool) {
        checkTask?.cancel()
        checkTask = Task {
            do {
                let release = try await fetchLatestRelease()
                try Task.checkCancellation()
                UserDefaults.standard.set(Date(), forKey: Self.lastCheckDefaultsKey)
                presentResult(for: release, silently: silently)
            } catch is CancellationError {
            } catch {
                if !silently {
                    showAlert(
                        title: "Update Check Failed",
                        message: "Could not reach GitHub to check for updates. \(error.localizedDescription)"
                    )
                }
            }
            checkTask = nil
        }
    }

    private func presentResult(for release: LatestRelease, silently: Bool) {
        guard let latest = AppVersion(release.tagName) else {
            if !silently {
                showAlert(
                    title: "Update Check Failed",
                    message: "Could not read the latest version number from GitHub (\"\(release.tagName)\")."
                )
            }
            return
        }

        guard let current = currentVersion else {
            if !silently {
                showAlert(
                    title: "Development Build",
                    message: "The latest release is \(release.tagName). This build was run from source and has no version number to compare.",
                    linkURL: release.htmlURL ?? Self.repositoryURL
                )
            }
            return
        }

        if current < latest {
            showAlert(
                title: "Update Available",
                message: "Owlign \(release.tagName) is available. You have \(currentVersionText). \(Self.updateInstructions)",
                linkURL: release.htmlURL ?? Self.repositoryURL
            )
        } else if !silently {
            showAlert(
                title: "You're Up to Date",
                message: "Owlign \(currentVersionText) is the latest version."
            )
        }
    }

    private func fetchLatestRelease() async throws -> LatestRelease {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LatestRelease.self, from: data)
    }

    private var currentVersion: AppVersion? {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }
        return AppVersion(string)
    }

    private var currentVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "an unversioned build"
    }

    private func showAlert(title: String, message: String, linkURL: URL? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        if let linkURL {
            alert.addButton(withTitle: "View on GitHub")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(linkURL)
            }
        } else {
            alert.runModal()
        }
    }
}
