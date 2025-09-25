import AppKit
import AppKitExtension
import Foundation
import Logger
import XcodeInspector

class Utils {
    public static func getXcode(by workspacePath: String) -> XcodeAppInstanceInspector? {
        return XcodeInspector.shared.xcodes.first(
            where: {
                $0.workspaceURL?.path == workspacePath
            })
    }
}
