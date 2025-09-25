import Foundation
import LanguageServerProtocol

public protocol FileWatcherProtocol {
    func startWatching() -> Bool
    func stopWatching()
}

public typealias PublisherType = (([FileEvent]) -> Void)

public protocol DirectoryWatcherProtocol: FileWatcherProtocol {
    func addPaths(_ paths: [URL])
    func removePaths(_ paths: [URL])
    func paths() -> [URL]
}

public protocol FileWatcherFactory {
    func createFileWatcher(
        fileURL: URL,
        dispatchQueue: DispatchQueue?,
        onFileModified: (() -> Void)?,
        onFileDeleted: (() -> Void)?,
        onFileRenamed: (() -> Void)?
    ) -> FileWatcherProtocol

    func createDirectoryWatcher(
        watchedPaths: [URL],
        changePublisher: @escaping PublisherType,
        publishInterval: TimeInterval,
        directoryChangePublisher: PublisherType?
    ) -> DirectoryWatcherProtocol
}
