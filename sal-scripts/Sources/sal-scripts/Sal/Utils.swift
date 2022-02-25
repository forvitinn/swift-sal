//
//  Utils.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import CloudKit
import CommonCrypto
import CryptoKit
import Foundation
import SWCompression
import SystemConfiguration

let ResultsPath = "/usr/local/sal/checkin_results.json"

// https://stackoverflow.com/questions/58177789
extension CharacterSet {
    static let whitespacesNewlinesAndNulls = CharacterSet.whitespacesAndNewlines.union(CharacterSet(["\0"]))
}

extension String {
    var boolValue: Bool {
        return (self as NSString).boolValue
    }
}

extension Dictionary {
    mutating func merge(dict: [Key: Value]) {
        for (k, v) in dict {
            updateValue(v, forKey: k)
        }
    }
}

func convertToListOfDictionary(text: String) -> [[String: Any]]? {
    if let data = text.data(using: .utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
        } catch {
            Log.debug(error.localizedDescription)
        }
    }
    return nil
}

func convertToDictionary(text: String) -> [String: Any]? {
    if let data = text.data(using: .utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            Log.debug(error.localizedDescription)
        }
    }
    return nil
}

func dictToJson(dictItem: [String: Any]) -> String {
    let jsonData = try! JSONSerialization.data(withJSONObject: dictItem, options: [.prettyPrinted])
    let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!

    return jsonString
}

func discardTimeZoneFromDate(_ theDate: Date) -> Date {
    /* Input: Date object
     Output: Date object with same date and time as the UTC.
     In Los Angeles (PDT), '2011-06-20T12:00:00Z' becomes
     '2011-06-20 12:00:00 -0700'.
     In New York (EDT), it becomes '2011-06-20 12:00:00 -0400'. */
    let timeZoneOffset = TimeZone.current.secondsFromGMT()
    return theDate.addingTimeInterval(TimeInterval(-timeZoneOffset))
}

func exec(command: String, arguments: [String] = [], wait: Bool? = false) -> (err: String, output: String) {
    let task = Process()

    task.executableURL = URL(fileURLWithPath: command)

    if arguments != [] {
        task.arguments = arguments
    }

    let outputPipe = Pipe()
    task.standardOutput = outputPipe

    let errorPipe = Pipe()
    task.standardError = errorPipe

    do {
        try task.run()
    } catch {
        Log.debug("Error running task. command: \(command). args: \(arguments)")
        return ("\(error)", "")
    }

    if wait! {
        task.waitUntilExit()
    }

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

    let output = String(decoding: outputData, as: UTF8.self)
    let error = String(decoding: errorData, as: UTF8.self)

    return (error, output)
}

func getUTCISOTime(date: Date) -> String {
    let localISOFormatter = ISO8601DateFormatter()
    // The default timeZone on DateFormatter is the device’s
    // local time zone. Set timeZone to UTC to get UTC time.
    localISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    localISOFormatter.timeZone = TimeZone(abbreviation: "UTC")

    return localISOFormatter.string(from: date)
}

func getUTCISOTimeFromString(dateString: String) -> Date {
    let localISOFormatter = ISO8601DateFormatter()
    // The default timeZone on DateFormatter is the device’s
    // local time zone. Set timeZone to UTC to get UTC time.
    localISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    localISOFormatter.timeZone = TimeZone(abbreviation: "UTC")

    return localISOFormatter.date(from: dateString)!
}

func stringFromDate(_ theDate: Date) -> String {
    // Input: NSDate object
    // Output: unicode object, date and time formatted per system locale.
    let df = DateFormatter()
    df.formatterBehavior = .behavior10_4
    df.dateStyle = .long
    df.timeStyle = .short
    return df.string(from: theDate)
}

func getHash(inputFile: String) -> String {
    var sha256 = ""
    if fileManager.fileExists(atPath: inputFile) {
        let fileUrl = URL(fileURLWithPath: inputFile)
        var handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: fileUrl)
        } catch {
            Log.error("Could not get hash of: \(inputFile)")
            return sha256
        }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let nextChunk = handle.readData(ofLength: SHA256.blockByteCount)
            guard !nextChunk.isEmpty else { return false }
            hasher.update(data: nextChunk)
            return true
        }) {}
        let digest = hasher.finalize()
        sha256 = digest.map { String(format: "%02hhx", $0) }.joined()
    }
    return sha256
}

func addPluginResults(plugin: String, data: String, historical: Bool = false) {
    /*
     Add data to the shared plugin results plist.
     
     This function creates the shared results plist file if it does not
     already exist; otherwise, it adds the entry by appending.
     Args:
         plugin (str): Name of the plugin returning data.
         data (dict): Dictionary of results.
         historical (bool): Whether to keep only one record (False) or
                            all results (True). Optional, defaults to False.
     */
    #if !os(macOS)
        Log.error("Please PR a plugin results path for your platform!")
        return
    #endif

    let plistPath = "/usr/local/sal/plugin_results.plist"
    var pluginResults = [[String: Any]?]()
    if fileManager.fileExists(atPath: plistPath) {
        do {
            pluginResults = try readPlist(plistPath) as! [[String: Any]]
        } catch {
            Log.error("Could not convert \(plistPath) to Dictionary")
            pluginResults = []
        }
    }
    pluginResults.append(["plugin": plugin, "historical": historical, "data": data])

    do {
        try writePlist(pluginResults, toFile: plistPath)
    } catch {
        Log.error("Could not update \(plistPath)")
    }
}

func getCheckinResults() -> [String: Any] {
    var results = [String: Any]()
    if fileManager.fileExists(atPath: ResultsPath) {
        let url = URL(fileURLWithPath: ResultsPath)
        do {
            let data = try Data(contentsOf: url)
            let JSON = try JSONSerialization.jsonObject(with: data, options: [])
            if let json = JSON as? [String: Any] {
                results = json
                return results
            }
        } catch {
            Log.debug("Could not read contents of \(ResultsPath)")
        }
    }
    return results
}

func cleanResults() {
    do {
        try fileManager.removeItem(atPath: ResultsPath)
        Log.debug("successfully remove \(ResultsPath)")
    } catch {
        Log.error("could not remove \(ResultsPath)")
    }
}

func saveResults(data: [String: Any]) {
    do {
        try writePlist(data, toFile: ResultsPath)
        Log.debug("successfully updated \(ResultsPath)")
    } catch {
        Log.error("could not update \(ResultsPath): \(error)")
    }

    writeJson(dataObject: data, filepath: ResultsPath)
}

func setCheckinResults(moduleName: String, data: Any) {
    var results = getCheckinResults()
    results[moduleName] = data

    saveResults(data: results)
}

func submissionEncode(input: Data) -> String {
    // compress the data and base64 encode it
    let compressedData = BZip2.compress(data: input)

    return compressedData.base64EncodedString()
}

func readBytesFromFile(filePath: String) -> Data? {
    if fileManager.fileExists(atPath: filePath) {
        do {
            let contents = try String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)
            return contents.data(using: .utf8)
        } catch {
            Log.debug("could not read \(filePath): \(error)")
            return nil
        }
    } else {
        return nil
    }
}

func dictionariesEqual(lhs: [String: Any], rhs: [String: Any]) -> Bool {
    return NSDictionary(dictionary: lhs).isEqual(to: rhs)
}
