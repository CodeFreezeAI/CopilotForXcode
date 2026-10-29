import AppKit
import AXExtension
import AXHelper
import ConversationServiceProvider
import Foundation
import JSONRPC
import Logger
import WebKit
import WebContentExtractor

public class FetchWebPageTool: ICopilotTool {
    public static let name = ToolName.fetchWebPage

    public func invokeTool(
        _ request: InvokeClientToolRequest,
        completion: @escaping (AnyJSONRPCResponse) -> Void,
        chatHistoryUpdater: ChatHistoryUpdater?,
        contextProvider: (any ToolContextProvider)?
    ) -> Bool {
        guard let params = request.params,
              let input = params.input,
              let urls = input["urls"]?.value as? [String]
        else {
            completeResponse(request, status: .error, response: "Invalid parameters", completion: completion)
            return true
        }
        
        guard !urls.isEmpty else {
            completeResponse(request, status: .error, response: "No valid URLs provided", completion: completion)
            return true
        }

        // Use the improved WebContentFetcher to fetch content from all URLs
        Task {
            let results = await WebContentFetcher.fetchMultipleContentAsync(from: urls)
            
            completeResponses(
                request,
                responses: results,
                completion: completion
            )
        }

        return true
    }
}
