//
//  Utils.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import Foundation
import SystemConfiguration

// https://stackoverflow.com/questions/58177789
extension CharacterSet {
    static let whitespacesNewlinesAndNulls = CharacterSet.whitespacesAndNewlines.union(CharacterSet(["\0"]))
}

extension Dictionary {
    mutating func merge(dict: [Key: Value]) {
        for (k, v) in dict {
            updateValue(v, forKey: k)
        }
    }
}

func dictToJson(dictItem: [String: Any]) -> Any {
    let jsonData = try! JSONSerialization.data(withJSONObject: dictItem, options: [])
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

func exec(command: String, arguments: [String] = []) -> (err: String, output: String) {
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

    task.waitUntilExit()

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
