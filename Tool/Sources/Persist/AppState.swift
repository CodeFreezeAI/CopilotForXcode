import CryptoKit
import Foundation
import JSONRPC
import Logger
import Status

public extension JSONValue {
    subscript(key: String) -> JSONValue? {
        if case .hash(let dict) = self {
            return dict[key]
        }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
    
    var numberValue: Double? {
        if case .number(let value) = self {
            return value
        }
        return nil
    }

    static func convertToJSONValue<T: Codable>(_ object: T) -> JSONValue? {
        do {
            let data = try JSONEncoder().encode(object)
            let jsonValue = try JSONDecoder().decode(JSONValue.self, from: data)
            return jsonValue
        } catch {
            Logger.client.info("Error converting to JSONValue: \(error)")
            return nil
        }
    }
}

public class AppState {
    public static let shared = AppState()

    private var cache: [String: [String: JSONValue]] = [:]
    private let cacheFileName = "appstate.json"
    private let queue = DispatchQueue(label: "com.github.AppStateCacheQueue")
    private var loadStatus: [String: Bool] = [:]

    private init() {
        cache[""] = [:] // initialize a default cache if no user exists
        initCacheForUserIfNeeded()
    }

    func toHash(contents: String, _ length: Int = 16) -> String {
        let data = Data(contents.utf8)
        let hashData = SHA256.hash(data: data)
        let hashValue = hashData.compactMap { String(format: "%02x", $0 ) }.joined()
        let index = hashValue.index(hashValue.startIndex, offsetBy: length)
        return String(hashValue[..<index])
    }

    public func update<T: Codable>(key: String, value: T) {
        queue.async {
            let userName = UserDefaults.shared.value(for: \.currentUserName)
            self.initCacheForUserIfNeeded(userName)
            self.cache[userName]![key] = JSONValue.convertToJSONValue(value)
            self.saveCacheForUser(userName)
        }
    }

    public func get(key: String) -> JSONValue? {
        return queue.sync {
            let userName = UserDefaults.shared.value(for: \.currentUserName)
            initCacheForUserIfNeeded(userName)
            return (self.cache[userName] ?? [:])[key]
        }
    }

    private func configFilePath(userName: String) -> URL {
        return ConfigPathUtils.configFilePath(userName: userName, fileName: cacheFileName)
    }

    private func saveCacheForUser(_ userName: String? = nil) {
        let user = userName ?? UserDefaults.shared.value(for: \.currentUserName)
        if !user.isEmpty { // save cache for non-empty user
            let cacheFilePath = configFilePath(userName: user)
            do {
                let data = try JSONEncoder().encode(self.cache[user] ?? [:])
                try data.write(to: cacheFilePath)
            } catch {
                Logger.client.info("Failed to save AppState cache: \(error)")
            }
        }
    }

    private func initCacheForUserIfNeeded(_ userName: String? = nil) {
        let user = userName ?? UserDefaults.shared.value(for: \.currentUserName)
        if !user.isEmpty, loadStatus[user] != true { // load cache for non-empty user
            self.loadStatus[user] = true
            self.cache[user] = [:]
            let cacheFilePath = configFilePath(userName: user)
            guard FileManager.default.fileExists(atPath: cacheFilePath.path) else {
                return
            }

            do {
                let data = try Data(contentsOf: cacheFilePath)
                self.cache[user] = try JSONDecoder().decode([String: JSONValue].self, from: data)
            } catch {
                Logger.client.info("Failed to load AppState cache: \(error)")
            }
        }
    }
}
