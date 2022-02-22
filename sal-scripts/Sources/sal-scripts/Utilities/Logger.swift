//
//  Logger.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import Foundation
import os

/*
 Combined ideas from http://www.filtercode.com/swift/logger-swift
 and https://gist.github.com/cbess/8fa7b9e2330a07020541 to get a logger
 closer to the python logger I was looking for.
 
 Log level is set based on a preference key that defaults to info if not set.
*/

struct Log {
    let file, function: String
    let line: Int
    
    init(file: String = #file, line: Int = #line, function: String = #function) {
        self.file = file
        self.line = line
        self.function = function
    }
    
    static func info(_ msg: String, file: String = #file, line: Int = #line, function: String = #function) {
        Logger.sharedInstance.logMessage(message: msg, logLevel: .Info, file: file, line: line, function: function)
    }

    static func debug(_ msg: String, file: String = #file, line: Int = #line, function: String = #function) {
        Logger.sharedInstance.logMessage(message: msg, logLevel: .Debug, file: file, line: line, function: function)
    }

    static func error(_ msg: String, file: String = #file, line: Int = #line, function: String = #function) {
        Logger.sharedInstance.logMessage(message: msg, logLevel: .Error, file: file, line: line, function: function)
    }
    
    static func warning(_ msg: String, file: String = #file, line: Int = #line, function: String = #function) {
        Logger.sharedInstance.logMessage(message: msg, logLevel: .Warning, file: file, line: line, function: function)
    }
}

enum LogLevel: Int {
    case None = 0
    case Warning
    case Error
    case Info
    case Debug
    case Custom
}

class Logger {
    var verbosityLevel: LogLevel = .Custom
//    var file: String = ""

    func loggerDate() -> String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return dateFormatter.string(from: date)
    }
    
    func logMessage(message: String , logLevel: LogLevel = .Info, file: String, line: Int, function: String) {

        if self.verbosityLevel.rawValue > LogLevel.None.rawValue && logLevel.rawValue <= self.verbosityLevel.rawValue {
            let fname = (file as NSString).lastPathComponent
            print("[\(self.loggerDate()) \(fname):\(function):\(line)] \(message)")
        }
    }

    class var sharedInstance: Logger {

        struct Singleton {
            static let instance = Logger()
        }

        return Singleton.instance
    }
}

func initLogger(logLevel: String) {
    switch logLevel {
    case "INFO":
        Logger.sharedInstance.verbosityLevel = .Info
        Logger.sharedInstance.logMessage(message: "Log level set to \(logLevel)", logLevel: .Info, file: #file, line: #line, function: #function)
    case "DEBUG":
        Logger.sharedInstance.verbosityLevel = .Debug
        Logger.sharedInstance.logMessage(message: "Log level set to \(logLevel)", logLevel: .Debug, file: #file, line: #line, function: #function)
    default:
        Logger.sharedInstance.verbosityLevel = .Info
        Logger.sharedInstance.logMessage(message: "Log level set to INFO", logLevel: .Info, file: #file, line: #line, function: #function)
    }
}

