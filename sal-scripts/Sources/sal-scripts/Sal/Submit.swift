//
//  Submit.swift
//  sal-scripts
//
//  Created by John Peterson on 1/17/22.
//

import Foundation
import ArgumentParser

struct Args {
    var debug: Bool = false
    var key: String = ""
    var url: String = ""
    var verbose: Bool = false
}
var args = Args()

extension URL {
    func subDirectories() throws -> [URL] {
        // @available(macOS 10.11, iOS 9.0, *)
        guard hasDirectoryPath else { return [] }
        return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter(\.hasDirectoryPath)
    }
}

struct ReadPreferences: ParsableCommand {
    @Option(name: .shortAndLong, help: "Enable full debug output.")
    var debug: Bool = false
    
    @Option(name: .shortAndLong, help: "Enable verbose output.")
    var verbose: Bool = false
  
    @Option(name: .shortAndLong, help: "Override the server URL for testing.")
    var url: String = ""
    
    @Option(name: .shortAndLong, help: "Override the machine group key.")
    var key: String = ""
    
    func run() throws -> ()  {
        args = Args(
            debug: debug, key: key, url: url, verbose: verbose
        )
  }
}

let CHECKIN_MODULES_DIR = "/usr/local/sal/checkin_modules"

func salSubmit() {
    getArgs()
    if args.debug || args.verbose {
        initLogger(logLevel: "DEBUG")
        
        
        var prefs = prefsReport()
        
        if !args.url.isEmpty {
            prefs["ServerURL"] = ["value": args.url, "forced": "commandline"]
        }
        
        if !args.key.isEmpty {
            prefs["key"] = ["value": args.key, "forced": "commandline"]
        }
        
        Log.debug("Sal client prefs:")
        for (key, value) in prefs {
            let val = (value as! [String:Any])
            let forced = (val["forced"]! as! Bool)
            var prefType = ""
            
            if !forced {
                prefType = "profile"
            } else {
                prefType = "prefs"
            }

            Log.debug("\t\(key): \(String(describing: val["value"]!)) \(prefType) ")
        }
    }
    let user = ProcessInfo().environment["USER"]
    if user! != "root" {
        Log.debug("Manually running this script requires sudo.")
        exit(3)
    }
    if waitForScript(scriptName: "sal-submit") {
        Log.debug("Another instance of sal-submit is already running. Exiting.")
        exit(3)
    }
    if waitForScript(scriptName: "managedsoftwareupdate") {
        Log.debug("managedsoftwareupdate is running. Exiting.")
        exit(3)
    }
    Log.info("Processing checkin modules...")
    
    let scriptResults = runScripts(directory:CHECKIN_MODULES_DIR, scriptArgs: [])
    for message in scriptResults {
        Log.debug(message)
    }
    
    let submission = getCheckinResults()
    let runType = getRunType(submission: submission)
    
    
    
}

func getArgs() {
    ReadPreferences.main()
}

func getRunType(submission: [String:Any]) -> String {
    var munki = [String:Any]()
    if let m = submission["Munki"] {
        munki = m as! [String : Any]
    }
    var munkiExtras = [String:Any]()
    if let e = munki["extra_data"] {
        munkiExtras = e as! [String : Any]
    }
 
    if let _ = munkiExtras["runtype"] {
        return munkiExtras["runtype"] as! String
    }

    return ""
}

func runPlugins(runType: String) {
    Log.info("Processing plugins...")
    let pluginResultsPath = "/usr/local/sal/plugin_results.plist"
}

func runExternalScripts(runType: String) {
    initLogger(logLevel: "DEBUG")
//    let externalScriptsDir = "/usr/local/sal/external_scripts"
    let externalScriptsDir = "/Users/john.peterson/Desktop/test"
    var isDir : ObjCBool = false
    if fileManager.fileExists(atPath: externalScriptsDir, isDirectory: &isDir) {
        if isDir.boolValue {
            //https://stackoverflow.com/questions/34388582/get-subdirectories-using-swift
            do {
                let url = URL(fileURLWithPath: externalScriptsDir)
                
                let subDirs = try url.subDirectories()
                
                for folder in subDirs {
                    if folder.lastPathComponent.starts(with: ".") {
                        continue
                    }
                    let scripts = try FileManager.default.contentsOfDirectory(at: folder.absoluteURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                    
                    for script in scripts {
                        if !fileManager.isExecutableFile(atPath:  script.path) {
                            Log.warning("\(script) is not executable! Skipping.")
                        } else {
                            let (err, _) = exec(command: script.path, arguments: [runType])
                            if err != "" {
                                Log.warning("\(script.path) had errors during execution")
                                continue
                            }
                            Log.debug("\(script) ran successfully")
                        }
                    }
                }
           } catch {
               Log.debug("error running script: \(error)")
           }
        }
    } else {
        Log.debug("\(externalScriptsDir) does not exist")
    }
}

func getPluginResults(pluginResultsPlist: String) -> [String:Any] {
    var plistData = [String:Any]()
    if fileManager.fileExists(atPath: pluginResultsPlist) {
        do {
            plistData = try readPlist(pluginResultsPlist) as! [String:Any]
        } catch {
            Log.warning("Could not read external data plist.")
        }
    } else {
        Log.warning("No external data plist found.")
    }
    return plistData
}

// https://www.hackingwithswift.com/articles/108/how-to-use-regular-expressions-in-swift
func removeBlocklistedMessages() {
    var update = false
    let patterns = salPref("MessageBlacklistPatterns") ?? "None"
    if (patterns as! String) == "None" {
        update = false
        var submission = getCheckinResults()
        

        for results in submission.values {
            if let res = results as? [String:Any] {
                
                var removals = [[String:Any]]()
                print(res.keys)
                if let message = res["messages"] as? [String:Any] {
                    print(res["messages"]!)

                    if let subject = message["text"] {
                        do {
                            let range = NSRange(location: 0, length: (subject as! String).utf16.count)
                            let regex = try! NSRegularExpression(pattern: patterns as! String)
                            if regex.firstMatch(in: subject as! String, options: [], range: range) != nil {
                                removals.append(message)
                            }
                        }

                    }
                }

                if removals.count > 0 {
                    update = true
                    for removal in removals {
                        Log.debug("Removing message \(removal)")
                        var r = results as! [String:Any]
                        r.removeValue(forKey: String(removal as! String))
                    }
                }

            } else {
                continue
            }
        }
    }
}
