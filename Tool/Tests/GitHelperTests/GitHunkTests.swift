import XCTest
import GitHelper

class GitHunkTests: XCTestCase {
    
    func testParseDiffSingleHunk() {
        let diff = """
        @@ -1,3 +1,4 @@
         line1
        +added line
         line2
         line3
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.startDeletedLine, 1)
        XCTAssertEqual(hunk.deletedLines, 3)
        XCTAssertEqual(hunk.startAddedLine, 1)
        XCTAssertEqual(hunk.addedLines, 4)
        XCTAssertEqual(hunk.additions.count, 1)
        XCTAssertEqual(hunk.additions[0].start, 2)
        XCTAssertEqual(hunk.additions[0].length, 1)
        XCTAssertEqual(hunk.diffText, " line1\n+added line\n line2\n line3")
    }
    
    func testParseDiffMultipleHunks() {
        let diff = """
        @@ -1,2 +1,3 @@
         line1
        +added line1
         line2
        @@ -10,2 +11,3 @@
         line10
        +added line10
         line11
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 2)
        
        // First hunk
        let hunk1 = hunks[0]
        XCTAssertEqual(hunk1.startDeletedLine, 1)
        XCTAssertEqual(hunk1.deletedLines, 2)
        XCTAssertEqual(hunk1.startAddedLine, 1)
        XCTAssertEqual(hunk1.addedLines, 3)
        XCTAssertEqual(hunk1.additions.count, 1)
        XCTAssertEqual(hunk1.additions[0].start, 2)
        XCTAssertEqual(hunk1.additions[0].length, 1)
        
        // Second hunk
        let hunk2 = hunks[1]
        XCTAssertEqual(hunk2.startDeletedLine, 10)
        XCTAssertEqual(hunk2.deletedLines, 2)
        XCTAssertEqual(hunk2.startAddedLine, 11)
        XCTAssertEqual(hunk2.addedLines, 3)
        XCTAssertEqual(hunk2.additions.count, 1)
        XCTAssertEqual(hunk2.additions[0].start, 12)
        XCTAssertEqual(hunk2.additions[0].length, 1)
    }
    
    func testParseDiffMultipleAdditions() {
        let diff = """
        @@ -1,5 +1,7 @@
         line1
        +added line1
        +added line2
         line2
         line3
        +added line3
         line4
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.additions.count, 2)
        
        // First addition block
        XCTAssertEqual(hunk.additions[0].start, 2)
        XCTAssertEqual(hunk.additions[0].length, 2)
        
        // Second addition block
        XCTAssertEqual(hunk.additions[1].start, 6)
        XCTAssertEqual(hunk.additions[1].length, 1)
    }
    
    func testParseDiffWithDeletions() {
        let diff = """
        @@ -1,4 +1,2 @@
         line1
        -deleted line1
        -deleted line2
         line2
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.startDeletedLine, 1)
        XCTAssertEqual(hunk.deletedLines, 4)
        XCTAssertEqual(hunk.startAddedLine, 1)
        XCTAssertEqual(hunk.addedLines, 2)
        XCTAssertEqual(hunk.additions.count, 0) // No additions, only deletions
    }
    
    func testParseDiffNewFile() {
        let diff = """
        @@ -0,0 +1,3 @@
        +line1
        +line2
        +line3
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.startDeletedLine, 1) // Should be adjusted from 0 to 1
        XCTAssertEqual(hunk.deletedLines, 0)
        XCTAssertEqual(hunk.startAddedLine, 1) // Should be adjusted from 0 to 1
        XCTAssertEqual(hunk.addedLines, 3)
        XCTAssertEqual(hunk.additions.count, 1)
        XCTAssertEqual(hunk.additions[0].start, 1)
        XCTAssertEqual(hunk.additions[0].length, 3)
    }
    
    func testParseDiffDeletedFile() {
        let diff = """
        @@ -1,3 +0,0 @@
        -line1
        -line2
        -line3
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.startDeletedLine, 1)
        XCTAssertEqual(hunk.deletedLines, 3)
        XCTAssertEqual(hunk.startAddedLine, 1) // Should be adjusted from 0 to 1
        XCTAssertEqual(hunk.addedLines, 0)
        XCTAssertEqual(hunk.additions.count, 0)
    }
    
    func testParseDiffSingleLineContext() {
        let diff = """
        @@ -1 +1,2 @@
         line1
        +added line
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.startDeletedLine, 1)
        XCTAssertEqual(hunk.deletedLines, 1) // Default when not specified
        XCTAssertEqual(hunk.startAddedLine, 1)
        XCTAssertEqual(hunk.addedLines, 2)
        XCTAssertEqual(hunk.additions.count, 1)
        XCTAssertEqual(hunk.additions[0].start, 2)
        XCTAssertEqual(hunk.additions[0].length, 1)
    }
    
    func testParseDiffEmptyString() {
        let diff = ""
        let hunks = GitHunk.parseDiff(diff)
        XCTAssertEqual(hunks.count, 0)
    }
    
    func testParseDiffInvalidFormat() {
        let diff = """
        invalid diff format
        no hunk headers
        """
        
        let hunks = GitHunk.parseDiff(diff)
        XCTAssertEqual(hunks.count, 0)
    }
    
    func testParseDiffTrailingNewline() {
        let diff = """
        @@ -1,2 +1,3 @@
         line1
        +added line
         line2
        
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.diffText, " line1\n+added line\n line2")
        XCTAssertFalse(hunk.diffText.hasSuffix("\n"))
    }
    
    func testParseDiffConsecutiveAdditions() {
        let diff = """
        @@ -1,3 +1,6 @@
         line1
        +added1
        +added2
        +added3
         line2
         line3
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.additions.count, 1)
        XCTAssertEqual(hunk.additions[0].start, 2)
        XCTAssertEqual(hunk.additions[0].length, 3)
    }
    
    func testParseDiffMixedChanges() {
        let diff = """
        @@ -1,6 +1,7 @@
         line1
        -deleted line
        +added line1
        +added line2
         line2
         line3
         line4
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.startDeletedLine, 1)
        XCTAssertEqual(hunk.deletedLines, 6)
        XCTAssertEqual(hunk.startAddedLine, 1)
        XCTAssertEqual(hunk.addedLines, 7)
        XCTAssertEqual(hunk.additions.count, 1)
        XCTAssertEqual(hunk.additions[0].start, 2)
        XCTAssertEqual(hunk.additions[0].length, 2)
    }
    
    func testParseDiffLargeLineNumbers() {
        let diff = """
        @@ -1000,5 +1000,6 @@
         line1000
        +added line
         line1001
         line1002
         line1003
         line1004
        """
        
        let hunks = GitHunk.parseDiff(diff)
        
        XCTAssertEqual(hunks.count, 1)
        let hunk = hunks[0]
        XCTAssertEqual(hunk.startDeletedLine, 1000)
        XCTAssertEqual(hunk.startAddedLine, 1000)
        XCTAssertEqual(hunk.additions.count, 1)
        XCTAssertEqual(hunk.additions[0].start, 1001)
        XCTAssertEqual(hunk.additions[0].length, 1)
    }
}
