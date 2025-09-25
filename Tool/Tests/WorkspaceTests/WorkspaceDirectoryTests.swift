import XCTest
import Foundation
@testable import Workspace

class WorkspaceDirectoryTests: XCTestCase {
    
    // MARK: - Directory Skip Pattern Tests
    
    func testShouldSkipDirectory() throws {
        // Test skip patterns at different positions in path
        XCTAssertTrue(WorkspaceDirectory.shouldSkipDirectory(URL(fileURLWithPath: "/some/path/.git")), "Should skip .git at end")
        XCTAssertTrue(WorkspaceDirectory.shouldSkipDirectory(URL(fileURLWithPath: "/some/.git/path")), "Should skip .git in middle")
        XCTAssertTrue(WorkspaceDirectory.shouldSkipDirectory(URL(fileURLWithPath: "/.git")), "Should skip .git at root")
        XCTAssertTrue(WorkspaceDirectory.shouldSkipDirectory(URL(fileURLWithPath: "/some/node_modules/package")), "Should skip node_modules in middle")
        XCTAssertTrue(WorkspaceDirectory.shouldSkipDirectory(URL(fileURLWithPath: "/project/Preview Content")), "Should skip Preview Content")
        XCTAssertTrue(WorkspaceDirectory.shouldSkipDirectory(URL(fileURLWithPath: "/project/.swiftpm")), "Should skip .swiftpm")
        
        XCTAssertFalse(WorkspaceDirectory.shouldSkipDirectory(URL(fileURLWithPath: "/some/valid/path")), "Should not skip valid paths")
        XCTAssertFalse(WorkspaceDirectory.shouldSkipDirectory(URL(fileURLWithPath: "/some/gitfile.txt")), "Should not skip files containing skip pattern in name")
    }
    
    // MARK: - Directory Validation Tests
    
    func testIsValidDirectory() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        
        do {
            // Create valid directory
            let validDirURL = try createSubdirectory(in: tmpDir, withName: "ValidDirectory")
            XCTAssertTrue(WorkspaceDirectory.isValidDirectory(validDirURL), "Valid directory should return true")
            
            // Create directory with skip pattern name
            let gitDirURL = try createSubdirectory(in: tmpDir, withName: ".git")
            XCTAssertFalse(WorkspaceDirectory.isValidDirectory(gitDirURL), ".git directory should return false")
            
            let nodeModulesDirURL = try createSubdirectory(in: tmpDir, withName: "node_modules")
            XCTAssertFalse(WorkspaceDirectory.isValidDirectory(nodeModulesDirURL), "node_modules directory should return false")
            
            let previewContentDirURL = try createSubdirectory(in: tmpDir, withName: "Preview Content")
            XCTAssertFalse(WorkspaceDirectory.isValidDirectory(previewContentDirURL), "Preview Content directory should return false")
            
            let swiftpmDirURL = try createSubdirectory(in: tmpDir, withName: ".swiftpm")
            XCTAssertFalse(WorkspaceDirectory.isValidDirectory(swiftpmDirURL), ".swiftpm directory should return false")
            
            // Test file (should return false)
            let fileURL = try createFile(in: tmpDir, withName: "file.swift", contents: "// Swift")
            XCTAssertFalse(WorkspaceDirectory.isValidDirectory(fileURL), "File should return false for isValidDirectory")
            
            // Test Xcode workspace directory (should return false due to shouldSkipURL)
            let xcworkspaceURL = try createSubdirectory(in: tmpDir, withName: "test.xcworkspace")
            _ = try createFile(in: xcworkspaceURL, withName: "contents.xcworkspacedata", contents: "")
            XCTAssertFalse(WorkspaceDirectory.isValidDirectory(xcworkspaceURL), "Xcode workspace should return false")
            
            // Test Xcode project directory (should return false due to shouldSkipURL)
            let xcprojectURL = try createSubdirectory(in: tmpDir, withName: "test.xcodeproj")
            _ = try createFile(in: xcprojectURL, withName: "project.pbxproj", contents: "")
            XCTAssertFalse(WorkspaceDirectory.isValidDirectory(xcprojectURL), "Xcode project should return false")
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Directory Enumeration Tests
    
    func testGetDirectoriesInActiveWorkspace() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        
        do {
            let myWorkspaceRoot = try createSubdirectory(in: tmpDir, withName: "myWorkspace")
            let xcWorkspaceURL = try createXCWorkspaceFolder(in: myWorkspaceRoot, withName: "myWorkspace.xcworkspace", fileRefs: [
                "container:myProject.xcodeproj",
                "group:../myDependency",])
            let _ = try createXCProjectFolder(in: myWorkspaceRoot, withName: "myProject.xcodeproj")
            let myDependencyURL = try createSubdirectory(in: tmpDir, withName: "myDependency")
            
            // Create valid directories
            let _ = try createSubdirectory(in: myWorkspaceRoot, withName: "Sources")
            let _ = try createSubdirectory(in: myWorkspaceRoot, withName: "Tests")
            let _ = try createSubdirectory(in: myDependencyURL, withName: "Library")
            
            // Create directories that should be skipped
            _ = try createSubdirectory(in: myWorkspaceRoot, withName: ".git")
            _ = try createSubdirectory(in: myWorkspaceRoot, withName: "node_modules")
            _ = try createSubdirectory(in: myWorkspaceRoot, withName: "Preview Content")
            _ = try createSubdirectory(in: myDependencyURL, withName: ".swiftpm")
            
            // Create some files (should be ignored)
            _ = try createFile(in: myWorkspaceRoot, withName: "file.swift", contents: "")
            _ = try createFile(in: myDependencyURL, withName: "file.swift", contents: "")
            
            let directories = WorkspaceDirectory.getDirectoriesInActiveWorkspace(
                workspaceURL: xcWorkspaceURL,
                workspaceRootURL: myWorkspaceRoot
            )
            let directoryNames = directories.map { $0.url.lastPathComponent }
            
            // Should include valid directories but not skipped ones
            XCTAssertTrue(directoryNames.contains("Sources"), "Should include Sources directory")
            XCTAssertTrue(directoryNames.contains("Tests"), "Should include Tests directory")
            XCTAssertTrue(directoryNames.contains("Library"), "Should include Library directory from dependency")
            
            // Should not include skipped directories
            XCTAssertFalse(directoryNames.contains(".git"), "Should not include .git directory")
            XCTAssertFalse(directoryNames.contains("node_modules"), "Should not include node_modules directory")
            XCTAssertFalse(directoryNames.contains("Preview Content"), "Should not include Preview Content directory")
            XCTAssertFalse(directoryNames.contains(".swiftpm"), "Should not include .swiftpm directory")
            
            // Should not include project metadata directories
            XCTAssertFalse(directoryNames.contains("myProject.xcodeproj"), "Should not include Xcode project directory")
            
        } catch {
            throw error
        }
    }
    
    func testGetDirectoriesInActiveWorkspaceWithSingleProject() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        
        do {
            let xcprojectURL = try createXCProjectFolder(in: tmpDir, withName: "myProject.xcodeproj")
            
            // Create valid directories
            let sourcesDir = try createSubdirectory(in: tmpDir, withName: "Sources")
            let _ = try createSubdirectory(in: tmpDir, withName: "Tests")
            
            // Create nested directory structure
            let _ = try createSubdirectory(in: sourcesDir, withName: "MyModule")
            
            // Create directories that should be skipped
            _ = try createSubdirectory(in: tmpDir, withName: ".git")
            _ = try createSubdirectory(in: tmpDir, withName: "Preview Content")
            
            let directories = WorkspaceDirectory.getDirectoriesInActiveWorkspace(
                workspaceURL: xcprojectURL,
                workspaceRootURL: tmpDir
            )
            let directoryNames = directories.map { $0.url.lastPathComponent }
            
            // Should include valid directories
            XCTAssertTrue(directoryNames.contains("Sources"), "Should include Sources directory")
            XCTAssertTrue(directoryNames.contains("Tests"), "Should include Tests directory")
            XCTAssertTrue(directoryNames.contains("MyModule"), "Should include nested MyModule directory")
            
            // Should not include skipped directories
            XCTAssertFalse(directoryNames.contains(".git"), "Should not include .git directory")
            XCTAssertFalse(directoryNames.contains("Preview Content"), "Should not include Preview Content directory")
            
            // Should not include project metadata
            XCTAssertFalse(directoryNames.contains("myProject.xcodeproj"), "Should not include Xcode project directory")
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Test Helper Methods
    // Following the DRY principle and Test Utility Pattern
    // https://martinfowler.com/bliki/ObjectMother.html
    
    func deleteDirectoryIfExists(at url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Failed to delete directory at \(url.path)")
            }
        }
    }
    
    func createTemporaryDirectory() throws -> URL {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let directoryName = UUID().uuidString
        let directoryURL = temporaryDirectoryURL.appendingPathComponent(directoryName)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
#if DEBUG
        print("Create temp directory \(directoryURL.path)")
#endif
        return directoryURL
    }
    
    func createSubdirectory(in directory: URL, withName name: String) throws -> URL {
        let subdirectoryURL = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true, attributes: nil)
        return subdirectoryURL
    }
    
    func createFile(in directory: URL, withName name: String, contents: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        let data = contents.data(using: .utf8)
        FileManager.default.createFile(atPath: fileURL.path, contents: data, attributes: nil)
        return fileURL
    }
    
    func createXCProjectFolder(in baseDirectory: URL, withName projectName: String) throws -> URL {
        let projectURL = try createSubdirectory(in: baseDirectory, withName: projectName)
        if projectName.hasSuffix(".xcodeproj") {
            _ = try createFile(in: projectURL, withName: "project.pbxproj", contents: "// Project file contents")
        }
        return projectURL
    }
    
    func createXCWorkspaceFolder(in baseDirectory: URL, withName workspaceName: String, fileRefs: [String]?) throws -> URL {
        let xcworkspaceURL = try createSubdirectory(in: baseDirectory, withName: workspaceName)
        if let fileRefs {
            _ = try createXCworkspacedataFile(directory: xcworkspaceURL, fileRefs: fileRefs)
        }
        return xcworkspaceURL
    }
    
    func createXCworkspacedataFile(directory: URL, fileRefs: [String]) throws -> URL {
        let contents = generateXCWorkspacedataContents(fileRefs: fileRefs)
        return try createFile(in: directory, withName: "contents.xcworkspacedata", contents: contents)
    }
    
    func generateXCWorkspacedataContents(fileRefs: [String]) -> String {
        var contents = """
        <?xml version="1.0" encoding="UTF-8"?>
           <Workspace
              version = "1.0">
        """
        for fileRef in fileRefs {
            contents += """
                <FileRef
                     location = "\(fileRef)">
                </FileRef>
            """
        }
        contents += "</Workspace>"
        return contents
    }
}
