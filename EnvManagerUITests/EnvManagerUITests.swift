import ApplicationServices
import XCTest

final class EnvManagerUITests: XCTestCase {
    private var workspace: UITestWorkspace!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        guard AXIsProcessTrusted() else {
            throw XCTSkip("UI tests require Accessibility access for Xcode and the UI test runner.")
        }

        workspace = try UITestWorkspace()
        try workspace.write(
            """
            export API_URL=https://example.com
            export PATH="/usr/bin:/bin"
            """,
            to: workspace.zshrcURL
        )

        app = XCUIApplication()
        app.launchEnvironment["ENV_MANAGER_HOME_OVERRIDE"] = workspace.homeURL.path
        app.launchEnvironment["ENV_MANAGER_BACKUP_DIRECTORY_OVERRIDE"] = workspace.backupsURL.path
        app.launchEnvironment["ENV_MANAGER_SHELL_OVERRIDE"] = "zsh"
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        workspace = nil
        try super.tearDownWithError()
    }

    func testDashboardLoadsFixtureConfiguration() {
        XCTAssertTrue(app.buttons["header-new-variable-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["user-variable-API_URL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shell-zsh-button"].exists)
        XCTAssertTrue(app.textFields["variable-search-field"].exists)
    }

    func testAddVariableFlowPersistsFixtureConfigAndCreatesBackup() throws {
        XCTAssertTrue(app.buttons["header-new-variable-button"].waitForExistence(timeout: 5))
        app.buttons["header-new-variable-button"].click()

        let nameField = app.textFields["variable-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.click()
        nameField.typeText("NEW_TOKEN")

        let valueField = app.textViews["variable-value-field"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 5))
        valueField.click()
        valueField.typeText("12345")

        app.buttons["variable-save-button"].click()

        let previewButton = app.buttons["preview-changes-button"]
        XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
        previewButton.click()

        XCTAssertTrue(app.staticTexts["preview-changes-text"].waitForExistence(timeout: 5))
        app.buttons["preview-apply-button"].click()

        try waitForFileToContain("export NEW_TOKEN=12345", at: workspace.zshrcURL)
        XCTAssertEqual(try workspace.backups().count, 1)
    }

    private func waitForFileToContain(_ expectedText: String, at url: URL, timeout: TimeInterval = 5) throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let contents = try? String(contentsOf: url, encoding: .utf8), contents.contains(expectedText) {
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail("Timed out waiting for \(url.path) to contain \(expectedText)")
    }
}

private final class UITestWorkspace {
    let rootURL: URL
    let homeURL: URL
    let backupsURL: URL

    var zshrcURL: URL { homeURL.appendingPathComponent(".zshrc") }

    init(fileManager: FileManager = .default) throws {
        rootURL = fileManager.temporaryDirectory.appendingPathComponent("EnvManagerUITests-\(UUID().uuidString)", isDirectory: true)
        homeURL = rootURL.appendingPathComponent("home", isDirectory: true)
        backupsURL = rootURL.appendingPathComponent("backups", isDirectory: true)

        try fileManager.createDirectory(at: homeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func backups() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }
}
