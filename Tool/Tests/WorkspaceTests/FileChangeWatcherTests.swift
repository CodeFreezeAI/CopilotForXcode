import ConversationServiceProvider
import CoreServices
import Foundation
import LanguageServerProtocol
@testable import Workspace
import XCTest

// MARK: - Mocks for Testing

class MockFSEventProvider: FSEventProvider {
    var createdStream: FSEventStreamRef?
    var didStartStream = false
    var didStopStream = false
    var didInvalidateStream = false
    var didReleaseStream = false
    var didSetDispatchQueue = false
    var registeredCallback: FSEventStreamCallback?
    var registeredContext: UnsafeMutablePointer<FSEventStreamContext>?
    
    var simulatedFiles: [String] = []
    
    func createEventStream(
        paths: CFArray,
        latency: CFTimeInterval,
        flags: UInt32,
        callback: @escaping FSEventStreamCallback,
        context: UnsafeMutablePointer<FSEventStreamContext>
    ) -> FSEventStreamRef? {
        registeredCallback = callback
        registeredContext = context
        let stream = unsafeBitCast(1, to: FSEventStreamRef.self)
        createdStream = stream
        return stream
    }
    
    func startStream(_ stream: FSEventStreamRef) {
        didStartStream = true
    }
    
    func stopStream(_ stream: FSEventStreamRef) {
        didStopStream = true
    }
    
    func invalidateStream(_ stream: FSEventStreamRef) {
        didInvalidateStream = true
    }
    
    func releaseStream(_ stream: FSEventStreamRef) {
        didReleaseStream = true
    }
    
    func setDispatchQueue(_ stream: FSEventStreamRef, queue: DispatchQueue) {
        didSetDispatchQueue = true
    }
}

class MockWorkspaceFileProvider: WorkspaceFileProvider {
    var subprojects: [URL] = []
    var filesInWorkspace: [ConversationFileReference] = []
    var xcProjectPaths: Set<String> = []
    var xcWorkspacePaths: Set<String> = []
    
    func getProjects(by workspaceURL: URL) -> [URL] {
        return subprojects
    }
    
    func getFilesInActiveWorkspace(workspaceURL: URL, workspaceRootURL: URL) -> [ConversationFileReference] {
        return filesInWorkspace
    }
    
    func isXCProject(_ url: URL) -> Bool {
        return xcProjectPaths.contains(url.path)
    }
    
    func isXCWorkspace(_ url: URL) -> Bool {
        return xcWorkspacePaths.contains(url.path)
    }

    func fileExists(atPath: String) -> Bool {
        return true
    }
}

class MockFileWatcher: FileWatcherProtocol {
    var fileURL: URL
    var dispatchQueue: DispatchQueue?
    var onFileModified: (() -> Void)?
    var onFileDeleted: (() -> Void)?
    var onFileRenamed: (() -> Void)?

    static var watchers = [URL: MockFileWatcher]()

    init(fileURL: URL, dispatchQueue: DispatchQueue? = nil, onFileModified: (() -> Void)? = nil, onFileDeleted: (() -> Void)? = nil, onFileRenamed: (() -> Void)? = nil) {
        self.fileURL = fileURL
        self.dispatchQueue = dispatchQueue
        self.onFileModified = onFileModified
        self.onFileDeleted = onFileDeleted
        self.onFileRenamed = onFileRenamed
        MockFileWatcher.watchers[fileURL] = self
    }

    func startWatching() -> Bool {
        return true
    }

    func stopWatching() {
        MockFileWatcher.watchers[fileURL] = nil
    }

    static func triggerFileDelete(for fileURL: URL) {
        guard let watcher = watchers[fileURL] else { return }
        watcher.onFileDeleted?()
    }
}

class MockFileWatcherFactory: FileWatcherFactory {
    func createFileWatcher(fileURL: URL, dispatchQueue: DispatchQueue?, onFileModified: (() -> Void)?, onFileDeleted: (() -> Void)?, onFileRenamed: (() -> Void)?) -> FileWatcherProtocol {
        return MockFileWatcher(fileURL: fileURL, dispatchQueue: dispatchQueue, onFileModified: onFileModified, onFileDeleted: onFileDeleted, onFileRenamed: onFileRenamed)
    }
    
    func createDirectoryWatcher(watchedPaths: [URL], changePublisher: @escaping PublisherType, publishInterval: TimeInterval, directoryChangePublisher: PublisherType?) -> DirectoryWatcherProtocol {
        return BatchingFileChangeWatcher(
            watchedPaths: watchedPaths,
            changePublisher: changePublisher,
            publishInterval: publishInterval,
            fsEventProvider: MockFSEventProvider(),
            directoryChangePublisher: directoryChangePublisher
        )
    }
}

// MARK: - Tests for BatchingFileChangeWatcher

final class BatchingFileChangeWatcherTests: XCTestCase {
    var mockFSEventProvider: MockFSEventProvider!
    var publishedEvents: [[FileEvent]] = []
    
    override func setUp() {
        super.setUp()
        mockFSEventProvider = MockFSEventProvider()
        publishedEvents = []
    }
    
    func createWatcher(projectURL: URL = URL(fileURLWithPath: "/test/project")) -> BatchingFileChangeWatcher {
        return BatchingFileChangeWatcher(
            watchedPaths: [projectURL],
            changePublisher: { [weak self] events in
                self?.publishedEvents.append(events)
            },
            publishInterval: 0.1,
            fsEventProvider: mockFSEventProvider
        )
    }
    
    func testInitSetsUpTimerAndFileWatching() {
        let _ = createWatcher()
        
        XCTAssertNotNil(mockFSEventProvider.createdStream)
        XCTAssertTrue(mockFSEventProvider.didStartStream)
    }
    
    func testDeinitCleansUpResources() {
        var watcher: BatchingFileChangeWatcher? = createWatcher()
        weak var weakWatcher = watcher
        
        watcher = nil
        
        // Wait for the watcher to be deallocated
        let startTime = Date()
        let timeout: TimeInterval = 1.0
        
        while weakWatcher != nil && Date().timeIntervalSince(startTime) < timeout {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        
        XCTAssertTrue(mockFSEventProvider.didStopStream)
        XCTAssertTrue(mockFSEventProvider.didInvalidateStream)
        XCTAssertTrue(mockFSEventProvider.didReleaseStream)
    }
    
    func testAddingEventsAndPublishing() {
        let watcher = createWatcher()
        let fileURL = URL(fileURLWithPath: "/test/project/file.swift")
        
        watcher.onFsEvent(url: fileURL, type: .created, isDirectory: false)
        
        // No events should be published yet
        XCTAssertTrue(publishedEvents.isEmpty)
        
        XCTAssertTrue(waitForPublishedEvents(), "No events were published within timeout")
        
        // Only verify array contents if we have events
        guard !publishedEvents.isEmpty else { return }
        
        XCTAssertEqual(publishedEvents[0].count, 1)
        XCTAssertEqual(publishedEvents[0][0].uri, fileURL.absoluteString)
        XCTAssertEqual(publishedEvents[0][0].type, .created)
    }
    
    func testProcessingFSEvents() {
        let watcher = createWatcher()
        let fileURL = URL(fileURLWithPath: "/test/project/file.swift")
        
        // Test file creation - directly call onFsEvent instead of removed methods
        watcher.onFsEvent(url: fileURL, type: .created, isDirectory: false)
        XCTAssertTrue(waitForPublishedEvents(), "No events were published within timeout")
        
        guard !publishedEvents.isEmpty else { return }
        XCTAssertEqual(publishedEvents[0].count, 1)
        XCTAssertEqual(publishedEvents[0][0].type, .created)
        
        // Test file modification
        publishedEvents = []
        watcher.onFsEvent(url: fileURL, type: .changed, isDirectory: false)
        
        XCTAssertTrue(waitForPublishedEvents(), "No events were published within timeout")
        
        guard !publishedEvents.isEmpty else { return }
        XCTAssertEqual(publishedEvents[0].count, 1)
        XCTAssertEqual(publishedEvents[0][0].type, .changed)
        
        // Test file deletion
        publishedEvents = []
        watcher.addEvent(file: fileURL, type: .deleted)
        XCTAssertTrue(waitForPublishedEvents(), "No events were published within timeout")
        
        guard !publishedEvents.isEmpty else { return }
        XCTAssertEqual(publishedEvents[0].count, 1)
        XCTAssertEqual(publishedEvents[0][0].type, .deleted)
    }
    
    // MARK: - Tests for Directory Change functionality
    
    func testDirectoryChangePublisherWithoutDirectoryPublisher() {
        // Test that directory events are ignored when no directoryChangePublisher is provided
        let watcher = createWatcher()
        let directoryURL = URL(fileURLWithPath: "/test/project/directory")
        
        // Call onFsEvent with directory = true
        watcher.onFsEvent(url: directoryURL, type: .created, isDirectory: true)
        
        // Wait a bit to ensure no events are published
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.publishedEvents.isEmpty, "No directory events should be published without directoryChangePublisher")
        }
    }
    
    func testDirectoryChangePublisherWithDirectoryPublisher() {
        var publishedDirectoryEvents: [[FileEvent]] = []
        
        let watcher = BatchingFileChangeWatcher(
            watchedPaths: [URL(fileURLWithPath: "/test/project")],
            changePublisher: { [weak self] events in
                self?.publishedEvents.append(events)
            },
            publishInterval: 0.1,
            fsEventProvider: mockFSEventProvider,
            directoryChangePublisher: { events in
                publishedDirectoryEvents.append(events)
            }
        )
        
        let directoryURL = URL(fileURLWithPath: "/test/project/directory")
        
        // Test directory creation
        watcher.onFsEvent(url: directoryURL, type: .created, isDirectory: true)
        
        // Wait for directory events to be published
        let start = Date()
        while publishedDirectoryEvents.isEmpty && Date().timeIntervalSince(start) < 1.0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        XCTAssertFalse(publishedDirectoryEvents.isEmpty, "Directory events should be published")
        XCTAssertEqual(publishedDirectoryEvents[0].count, 1)
        XCTAssertEqual(publishedDirectoryEvents[0][0].uri, directoryURL.absoluteString)
        XCTAssertEqual(publishedDirectoryEvents[0][0].type, .created)
        
        // Test directory modification
        publishedDirectoryEvents = []
        watcher.onFsEvent(url: directoryURL, type: .changed, isDirectory: true)
        
        let start2 = Date()
        while publishedDirectoryEvents.isEmpty && Date().timeIntervalSince(start2) < 1.0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        XCTAssertFalse(publishedDirectoryEvents.isEmpty, "Directory change events should be published")
        XCTAssertEqual(publishedDirectoryEvents[0][0].type, .changed)
        
        // Test directory deletion
        publishedDirectoryEvents = []
        watcher.onFsEvent(url: directoryURL, type: .deleted, isDirectory: true)
        
        let start3 = Date()
        while publishedDirectoryEvents.isEmpty && Date().timeIntervalSince(start3) < 1.0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        XCTAssertFalse(publishedDirectoryEvents.isEmpty, "Directory deletion events should be published")
        XCTAssertEqual(publishedDirectoryEvents[0][0].type, .deleted)
    }
    
    // MARK: - Tests for onFsEvent method
    
    func testOnFsEventWithFileOperations() {
        let watcher = createWatcher()
        let fileURL = URL(fileURLWithPath: "/test/project/file.swift")
        
        // Test file creation via onFsEvent
        watcher.onFsEvent(url: fileURL, type: .created, isDirectory: false)
        XCTAssertTrue(waitForPublishedEvents(), "File creation event should be published")
        
        guard !publishedEvents.isEmpty else { return }
        XCTAssertEqual(publishedEvents[0][0].type, .created)
        
        // Test file modification via onFsEvent
        publishedEvents = []
        watcher.onFsEvent(url: fileURL, type: .changed, isDirectory: false)
        XCTAssertTrue(waitForPublishedEvents(), "File change event should be published")
        
        guard !publishedEvents.isEmpty else { return }
        XCTAssertEqual(publishedEvents[0][0].type, .changed)
        
        // Test file deletion via onFsEvent
        publishedEvents = []
        watcher.onFsEvent(url: fileURL, type: .deleted, isDirectory: false)
        XCTAssertTrue(waitForPublishedEvents(), "File deletion event should be published")
        
        guard !publishedEvents.isEmpty else { return }
        XCTAssertEqual(publishedEvents[0][0].type, .deleted)
    }
    
    func testOnFsEventWithNilIsDirectory() {
        var publishedDirectoryEvents: [[FileEvent]] = []
        
        let watcher = BatchingFileChangeWatcher(
            watchedPaths: [URL(fileURLWithPath: "/test/project")],
            changePublisher: { [weak self] events in
                self?.publishedEvents.append(events)
            },
            publishInterval: 0.1,
            fsEventProvider: mockFSEventProvider,
            directoryChangePublisher: { events in
                publishedDirectoryEvents.append(events)
            }
        )
        
        let fileURL = URL(fileURLWithPath: "/test/project/file.swift")
        
        // Test deletion with nil isDirectory (should trigger both file and directory deletion)
        watcher.onFsEvent(url: fileURL, type: .deleted, isDirectory: nil)
        
        // Wait for both file and directory events
        let start = Date()
        while (publishedEvents.isEmpty || publishedDirectoryEvents.isEmpty) && Date().timeIntervalSince(start) < 1.0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        XCTAssertFalse(publishedEvents.isEmpty, "File deletion event should be published")
        XCTAssertFalse(publishedDirectoryEvents.isEmpty, "Directory deletion event should be published")
        XCTAssertEqual(publishedEvents[0][0].type, .deleted)
        XCTAssertEqual(publishedDirectoryEvents[0][0].type, .deleted)
    }
    
    // MARK: - Tests for Event Compression
    
    func testEventCompression() {
        let watcher = createWatcher()
        let fileURL = URL(fileURLWithPath: "/test/project/file.swift")
        
        // Add multiple events for the same file
        watcher.addEvent(file: fileURL, type: .created)
        watcher.addEvent(file: fileURL, type: .changed)
        watcher.addEvent(file: fileURL, type: .deleted)
        
        XCTAssertTrue(waitForPublishedEvents(), "Events should be published")
        
        guard !publishedEvents.isEmpty else { return }
        
        // Should be compressed to only deletion event (deletion covers creation and change)
        XCTAssertEqual(publishedEvents[0].count, 1)
        XCTAssertEqual(publishedEvents[0][0].type, .deleted)
    }
    
    func testEventCompressionCreatedOverridesDeleted() {
        let watcher = createWatcher()
        let fileURL = URL(fileURLWithPath: "/test/project/file.swift")
        
        // Add deletion then creation
        watcher.addEvent(file: fileURL, type: .deleted)
        watcher.addEvent(file: fileURL, type: .created)
        
        XCTAssertTrue(waitForPublishedEvents(), "Events should be published")
        
        guard !publishedEvents.isEmpty else { return }
        
        // Should be compressed to only creation event (creation overrides deletion)
        XCTAssertEqual(publishedEvents[0].count, 1)
        XCTAssertEqual(publishedEvents[0][0].type, .created)
    }
    
    func testEventCompressionChangeDoesNotOverrideCreated() {
        let watcher = createWatcher()
        let fileURL = URL(fileURLWithPath: "/test/project/file.swift")
        
        // Add creation then change
        watcher.addEvent(file: fileURL, type: .created)
        watcher.addEvent(file: fileURL, type: .changed)
        
        XCTAssertTrue(waitForPublishedEvents(), "Events should be published")
        
        guard !publishedEvents.isEmpty else { return }
        
        // Should keep creation event (change doesn't override creation)
        XCTAssertEqual(publishedEvents[0].count, 1)
        XCTAssertEqual(publishedEvents[0][0].type, .created)
    }
    
    func testEventCompressionMultipleFiles() {
        let watcher = createWatcher()
        let file1URL = URL(fileURLWithPath: "/test/project/file1.swift")
        let file2URL = URL(fileURLWithPath: "/test/project/file2.swift")
        
        // Add events for multiple files
        watcher.addEvent(file: file1URL, type: .created)
        watcher.addEvent(file: file2URL, type: .created)
        watcher.addEvent(file: file1URL, type: .changed)
        
        XCTAssertTrue(waitForPublishedEvents(), "Events should be published")
        
        guard !publishedEvents.isEmpty else { return }
        
        // Should have 2 events, one for each file
        XCTAssertEqual(publishedEvents[0].count, 2)
        
        // file1 should be created (changed doesn't override created)
        // file2 should be created
        let eventTypes = publishedEvents[0].map { $0.type }
        XCTAssertTrue(eventTypes.contains(.created))
        XCTAssertEqual(eventTypes.filter { $0 == .created }.count, 2)
    }
}

extension BatchingFileChangeWatcherTests {
    func waitForPublishedEvents(timeout: TimeInterval = 1.0) -> Bool {
        let start = Date()
        while publishedEvents.isEmpty && Date().timeIntervalSince(start) < timeout {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return !publishedEvents.isEmpty
    }
}

// MARK: - Tests for FileChangeWatcherService

final class FileChangeWatcherServiceTests: XCTestCase {
    var mockWorkspaceFileProvider: MockWorkspaceFileProvider!
    var publishedEvents: [[FileEvent]] = []
    
    override func setUp() {
        super.setUp()
        mockWorkspaceFileProvider = MockWorkspaceFileProvider()
        publishedEvents = []
    }
    
    func createService(workspaceURL: URL = URL(fileURLWithPath: "/test/workspace")) -> FileChangeWatcherService {
        return FileChangeWatcherService(
            workspaceURL,
            publisher: { [weak self] events in
                self?.publishedEvents.append(events)
            },
            publishInterval: 0.1,
            workspaceFileProvider: mockWorkspaceFileProvider,
            watcherFactory: MockFileWatcherFactory(), 
            directoryChangePublisher: nil
        )
    }
    
    func testStartWatchingCreatesWatchersForProjects() {
        let project1 = URL(fileURLWithPath: "/test/workspace/project1")
        let project2 = URL(fileURLWithPath: "/test/workspace/project2")
        mockWorkspaceFileProvider.subprojects = [project1, project2]
        
        let service = createService()
        service.startWatching()
        
        XCTAssertNotNil(service.watcher)
        XCTAssertEqual(service.watcher?.paths().count, 2)
        XCTAssertEqual(service.watcher?.paths(), [project1, project2])
    }
    
    func testStartWatchingDoesNotCreateWatcherForRootDirectory() {
        let service = createService(workspaceURL: URL(fileURLWithPath: "/"))
        service.startWatching()
        
        XCTAssertNil(service.watcher)
    }
    
    func testProjectMonitoringDetectsAddedProjects() {
        let workspace = URL(fileURLWithPath: "/test/workspace")
        let project1 = URL(fileURLWithPath: "/test/workspace/project1")
        mockWorkspaceFileProvider.subprojects = [project1]
        mockWorkspaceFileProvider.xcWorkspacePaths = [workspace.path]
        
        let service = createService(workspaceURL: workspace)
        service.startWatching()
        
        XCTAssertNotNil(service.watcher)
        
        // Simulate adding a new project
        let project2 = URL(fileURLWithPath: "/test/workspace/project2")
        mockWorkspaceFileProvider.subprojects = [project1, project2]
        
        // Set up mock files for the added project
        let file1URL = URL(fileURLWithPath: "/test/workspace/project2/file1.swift")
        let file1 = ConversationFileReference(
            url: file1URL,
            relativePath: file1URL.relativePath,
            fileName: file1URL.lastPathComponent
        )
        let file2URL = URL(fileURLWithPath: "/test/workspace/project2/file2.swift")
        let file2 = ConversationFileReference(
            url: file2URL,
            relativePath: file2URL.relativePath,
            fileName: file2URL.lastPathComponent
        )
        mockWorkspaceFileProvider.filesInWorkspace = [file1, file2]

        MockFileWatcher.triggerFileDelete(for: workspace.appendingPathComponent("contents.xcworkspacedata"))
        
        XCTAssertTrue(waitForPublishedEvents(), "No events were published within timeout")
        
        guard !publishedEvents.isEmpty else { return }
        
        // Verify file events were published
        XCTAssertEqual(publishedEvents[0].count, 2)
        
        // Verify both files were reported as created
        XCTAssertEqual(publishedEvents[0][0].type, .created)
        XCTAssertEqual(publishedEvents[0][1].type, .created)
    }
    
    func testProjectMonitoringDetectsRemovedProjects() {
        let workspace = URL(fileURLWithPath: "/test/workspace")
        let project1 = URL(fileURLWithPath: "/test/workspace/project1")
        let project2 = URL(fileURLWithPath: "/test/workspace/project2")
        mockWorkspaceFileProvider.subprojects = [project1, project2]
        mockWorkspaceFileProvider.xcWorkspacePaths = [workspace.path]
        
        let service = createService(workspaceURL: workspace)
        service.startWatching()
        
        XCTAssertNotNil(service.watcher)
        
        // Simulate removing a project
        mockWorkspaceFileProvider.subprojects = [project1]
        
        // Set up mock files for the removed project
        let file1URL = URL(fileURLWithPath: "/test/workspace/project2/file1.swift")
        let file1 = ConversationFileReference(
            url: file1URL,
            relativePath: file1URL.relativePath,
            fileName: file1URL.lastPathComponent
        )
        let file2URL = URL(fileURLWithPath: "/test/workspace/project2/file2.swift")
        let file2 = ConversationFileReference(
            url: file2URL,
            relativePath: file2URL.relativePath,
            fileName: file2URL.lastPathComponent
        )
        mockWorkspaceFileProvider.filesInWorkspace = [file1, file2]
        
        // Clear published events from setup
        publishedEvents = []

        MockFileWatcher.triggerFileDelete(for: workspace.appendingPathComponent("contents.xcworkspacedata"))
                
        XCTAssertTrue(waitForPublishedEvents(), "No events were published within timeout")
            
        guard !publishedEvents.isEmpty else { return }
        
        // Verify file events were published
        XCTAssertEqual(publishedEvents[0].count, 2)
        
        // Verify both files were reported as deleted
        XCTAssertEqual(publishedEvents[0][0].type, .deleted)
        XCTAssertEqual(publishedEvents[0][1].type, .deleted)
    }
}

extension FileChangeWatcherServiceTests {
    func waitForPublishedEvents(timeout: TimeInterval = 3.0) -> Bool {
        let start = Date()
        while publishedEvents.isEmpty && Date().timeIntervalSince(start) < timeout {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return !publishedEvents.isEmpty
    }
}
