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
    static func info(_ msg: String) {
        Logger.sharedInstance.logMessage(message: msg, .Info)
    }

    static func debug(_ msg: String) {
        Logger.sharedInstance.logMessage(message: msg, .Debug)
    }

    static func error(_ msg: String) {
        Logger.sharedInstance.logMessage(message: msg, .Error)
    }
    
    static func warning(_ msg: String) {
        Logger.sharedInstance.logMessage(message: msg, .Warning)
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

    func loggerDate() -> String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return dateFormatter.string(from: date)
    }
    
    func logMessage(message: String , _ logLevel: LogLevel = .Info, file: String = #file, line: Int = #line, funcName: String = #function) {

        if self.verbosityLevel.rawValue > LogLevel.None.rawValue && logLevel.rawValue <= self.verbosityLevel.rawValue {
            let fname = (file as NSString).lastPathComponent
            print("[\(self.loggerDate()) \(fname):\(funcName):\(line)] \(message)")
        }
    }

    class var sharedInstance: Logger {

        struct Singleton {
            static let instance = Logger()
        }

        return Singleton.instance
    }
}

func initLogger() {
    let logLevel = pref("LogLevel", salPrefDomain) ?? "INFO"
    
    switch (logLevel as! String) {
    case "INFO":
        Logger.sharedInstance.verbosityLevel = .Info
    case "DEBUG":
        Logger.sharedInstance.verbosityLevel = .Debug
    default:
        Logger.sharedInstance.verbosityLevel = .Info
    }
   
    Logger.sharedInstance.logMessage(message: "Log level set to \(logLevel)", .Debug)
}

