import XCTest
@testable import EnvManager

@MainActor
final class EnvironmentIntegrationTests: XCTestCase {
    private var workspace: TestWorkspace!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workspace = try TestWorkspace()
    }

    override func tearDownWithError() throws {
        workspace = nil
        try super.tearDownWithError()
    }

    func testSaveChangesWritesPreviewCreatesBackupAndReloadsState() throws {
        let originalContent = """
        # Existing config
        export PATH="/usr/bin:/bin"
        export API_URL=https://old.example.com
        """
        try workspace.write(originalContent, to: workspace.zshrcURL)

        let writer = ShellConfigWriter(backupDirectory: workspace.backupsURL)
        let viewModel = EnvironmentViewModel(
            writer: writer,
            initialShell: .zsh,
            initialConfigFile: workspace.zshrcURL.path
        )

        viewModel.loadConfiguration()

        var apiURL = try XCTUnwrap(viewModel.userVariables.first { $0.name == "API_URL" })
        let pathVariable = try XCTUnwrap(viewModel.userVariables.first { $0.name == "PATH" })

        apiURL.value = "https://new.example.com"
        viewModel.updateVariable(apiURL)
        viewModel.addVariable(EnvironmentVariable(name: "FEATURE_FLAG", value: "enabled"))
        viewModel.deleteVariable(pathVariable)

        let preview = viewModel.previewChanges()
        XCTAssertTrue(preview.contains(#"# export PATH="/usr/bin:/bin" # Removed by EnvManager"#))
        XCTAssertTrue(preview.contains("export API_URL=https://new.example.com"))
        XCTAssertTrue(preview.contains("export FEATURE_FLAG=enabled"))

        try viewModel.saveChanges()

        XCTAssertEqual(try workspace.read(workspace.zshrcURL), preview)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
        XCTAssertEqual(viewModel.userVariables.map(\.name).sorted(), ["API_URL", "FEATURE_FLAG"])

        let backups = try workspace.backups()
        XCTAssertEqual(backups.count, 1)
        let backup = try XCTUnwrap(backups.first)
        XCTAssertEqual(try workspace.read(backup), originalContent)
    }

    func testSaveChangesCreatesMissingConfigFileWhenNeeded() throws {
        let viewModel = EnvironmentViewModel(
            writer: ShellConfigWriter(backupDirectory: workspace.backupsURL),
            initialShell: .bash,
            initialConfigFile: workspace.bashrcURL.path
        )

        viewModel.loadConfiguration()
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.bashrcURL.path))

        viewModel.addVariable(EnvironmentVariable(name: "EDITOR", value: "vim"))
        try viewModel.saveChanges()

        let savedContent = try workspace.read(workspace.bashrcURL)
        XCTAssertTrue(savedContent.contains("# ~/.bashrc - Bash configuration"))
        XCTAssertTrue(savedContent.contains("export EDITOR=vim"))
        XCTAssertTrue(try workspace.backups().isEmpty)
    }

    func testDuplicateAdditionReusesPendingEntryInsteadOfAppendingTwice() throws {
        let viewModel = EnvironmentViewModel(
            writer: ShellConfigWriter(backupDirectory: workspace.backupsURL),
            initialShell: .zsh,
            initialConfigFile: workspace.zshrcURL.path
        )

        viewModel.loadConfiguration()
        viewModel.addVariable(EnvironmentVariable(name: "EDITOR", value: "vim"))
        viewModel.addVariable(EnvironmentVariable(name: "EDITOR", value: "nvim"))

        let preview = viewModel.previewChanges()
        XCTAssertEqual(preview.components(separatedBy: "export EDITOR=").count - 1, 1)
        XCTAssertTrue(preview.contains("export EDITOR=nvim"))

        try viewModel.saveChanges()
        XCTAssertEqual(try workspace.read(workspace.zshrcURL).components(separatedBy: "export EDITOR=").count - 1, 1)
    }

    func testFishPathVariablesNormalizeIntoColonSeparatedValue() throws {
        try workspace.write(
            """
            set -gx PATH /usr/local/bin /opt/homebrew/bin
            set -gx JAVA_HOME /Library/Java/JavaVirtualMachines/current
            """,
            to: workspace.fishConfigURL
        )

        let config = try XCTUnwrap(
            ShellConfigParser().parseConfigFile(at: workspace.fishConfigURL.path, shellType: .fish)
        )

        let pathVariable = try XCTUnwrap(config.variables.first { $0.name == "PATH" })
        XCTAssertEqual(pathVariable.value, "/usr/local/bin:/opt/homebrew/bin")
    }
}

private final class TestWorkspace {
    let rootURL: URL
    let homeURL: URL
    let backupsURL: URL

    var zshrcURL: URL { homeURL.appendingPathComponent(".zshrc") }
    var bashrcURL: URL { homeURL.appendingPathComponent(".bashrc") }
    var fishConfigURL: URL { homeURL.appendingPathComponent(".config/fish/config.fish") }

    init(fileManager: FileManager = .default) throws {
        rootURL = fileManager.temporaryDirectory.appendingPathComponent("EnvManagerTests-\(UUID().uuidString)", isDirectory: true)
        homeURL = rootURL.appendingPathComponent("home", isDirectory: true)
        backupsURL = rootURL.appendingPathComponent("backups", isDirectory: true)

        try fileManager.createDirectory(at: homeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: fishConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func read(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func backups() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
