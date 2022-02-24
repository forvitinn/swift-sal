//
//  Submit.swift
//  sal-scripts
//
//  Created by John Peterson on 1/17/22.
//
import ArgumentParser
import Foundation

struct Args {
    var debug: Bool = false
    var key: String = ""
    var url: String = ""
    var verbose: Bool = false

    var scripts: Bool = false
    var pre: Bool = false
    var post: Bool = false

    var random: Bool = false
    var delay = UInt32()
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

    @Option(name: .shortAndLong, help: "Delay in seconds before running.")
    var delay: UInt32 = 0

    @Option(name: .shortAndLong, help: "Randomize delay time.")
    var random: Bool = false

    @Flag(help: "If set, run munki pre/post install scripts.")
    var scripts: Bool = false

    @Flag(name: .long, help: "Run munki preflight script.")
    var pre: Bool = false

    @Flag(name: .long, help: "Run munki postflight script.")
    var post: Bool = false

    func run() throws {
        args = Args(
            debug: debug,
            key: key,
            url: url,
            verbose: verbose,
            scripts: scripts,
            pre: pre,
            post: post,
            random: random,
            delay: delay
        )
    }
}

let CHECKIN_MODULES_DIR = "/usr/local/sal/checkin_modules"

func salSubmit() {
    getArgs()
    initLogger(logLevel: "INFO")
    if args.debug || args.verbose {
        initLogger(logLevel: "DEBUG")
    }

    if args.delay != nil {
        if args.random {
            let randomInt = Int.random(in: 0 ... Int(args.delay))
            sleep(UInt32(randomInt))
        } else {
            sleep(args.delay)
        }
    }

    if args.scripts {
        if args.pre {
            munkiPreFlight()
            exit(0)
        }

        if args.post {
            munkiPostFlight()
            exit(0)
        }
    }
    var prefs = prefsReport()

    if !args.url.isEmpty {
        prefs["ServerURL"] = ["value": args.url, "forced": "commandline"]
    }

    if !args.key.isEmpty {
        prefs["key"] = ["value": args.key, "forced": "commandline"]
    }

    var prefType = ""
    Log.debug("Sal client prefs:")
    for (key, value) in prefs {
        let val = (value as! [String: Any])
        if let forced = (val["forced"] as? Bool) {
            if forced {
                prefType = "profile"
            } else {
                prefType = "prefs"
            }
        } else if (val["forced"] as? String) == "commandline" {
            prefType = "prefs"
        }
        Log.debug("\t\(key): \(String(describing: val["value"]!)) \(prefType) ")
    }
    let user = ProcessInfo().environment["USER"]
    if user! != "root" {
        Log.info("Manually running this script requires sudo.")
//        exit(3)
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

    let scriptResults = gatherInfo()
    saveResults(data: scriptResults)

    for message in scriptResults.keys {
        Log.debug(message)
    }
    var report = getCheckinResults()

    let submission = getCheckinResults()
    let runType = getRunType(submission: submission)

    runPlugins(runType: runType)

    let client = setupSalClient()

    if args.url != "" {
        client.baseUrl(url: args.url)
        Log.debug("Server URL overridden with \(args.url)")
    }

    if args.key != "" {
        client.auth(creds: ["sal", args.key])
        // override the key in the report since its used
        // for querying.
        if let _ = report["Sal"] as? [String: [String: Any]] {
            var update = report["Sal"] as? [String: [String: Any]]
            update!["extra_data"]!.updateValue(args.key, forKey: "key")
            report.updateValue(update as Any, forKey: "Sal")
        }
        Log.debug("Machine group key overridden with \(args.key)")
    }

    let (res, response) = sendCheckin(report: report, client: client)

    if response.statusCode == 200 {
        setPref("LastCheckDate", getUTCISOTime(date: Date()))
        cleanResults()
    }

    /*
      Speed up manual runs by skipping these potentially slow-running,
      and infrequently changing tasks.
     */
    sendInventory(serial: getSerialNumber(), client: client)
}

func getArgs() {
    ReadPreferences.main()
}

func getRunType(submission: [String: Any]) -> String {
    var munki = [String: Any]()
    if let m = submission["Munki"] {
        munki = m as! [String: Any]
    }
    var munkiExtras = [String: Any]()
    if let e = munki["extra_data"] {
        munkiExtras = e as! [String: Any]
    }

    if let _ = munkiExtras["runtype"] {
        return munkiExtras["runtype"] as! String
    }

    return ""
}

func runPlugins(runType: String) {
    Log.info("Processing plugins...")
    let pluginResultsPath = "/usr/local/sal/plugin_results.plist"

    runExternalScripts(runType: runType)
    let pluginResults = getPluginResults(pluginResultsPlist: pluginResultsPath)
    do {
        try FileManager.default.removeItem(atPath: pluginResultsPath)
    } catch {
        Log.debug("Error removing temporary profile directory")
    }

    setCheckinResults(moduleName: "plugin_results", data: pluginResults)
    
}

func runExternalScripts(runType: String) {
    let externalScriptsDir = "/usr/local/sal/external_scripts"

    var isDir: ObjCBool = false
    if fileManager.fileExists(atPath: externalScriptsDir, isDirectory: &isDir) {
        if isDir.boolValue {
            // https://stackoverflow.com/questions/34388582/get-subdirectories-using-swift
            do {
                let url = URL(fileURLWithPath: externalScriptsDir)

                let subDirs = try url.subDirectories()

                for folder in subDirs {
                    if folder.lastPathComponent.starts(with: ".") {
                        continue
                    }
                    let scripts = try FileManager.default.contentsOfDirectory(at: folder.absoluteURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

                    for script in scripts {
                        if !fileManager.isExecutableFile(atPath: script.path) {
                            Log.warning("\(script) is not executable! Skipping.")
                        } else {
                            let (err, _) = exec(command: script.path, arguments: [runType])
                            if err != "" {
                                Log.warning("\(script.path) had errors during execution: \(err)")
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

func getPluginResults(pluginResultsPlist: String) -> Any {
    if fileManager.fileExists(atPath: pluginResultsPlist) {
        do {
            let plistData = try readPlist(pluginResultsPlist)
            if let result = plistData as? [String: Any] {
                return result
            } else if let result = plistData as? [[String: Any]] {
                var res = [String: Any]()
                for item in result {
                    for (key, value) in item {
                        res.updateValue(value, forKey: key)
                    }
                }
                return res
            } else {
                Log.debug("unknown plistData format")
            }

        } catch {
            Log.warning("Could not read external data plist.")
        }
    } else {
        Log.warning("No external data plist found.")
    }
    return [String: Any]()
}

// https://www.hackingwithswift.com/articles/108/how-to-use-regular-expressions-in-swift
func removeBlocklistedMessages() {
    var update = false
    let patterns = salPref("MessageBlacklistPatterns")

    if (patterns as! String) == "None" {
        let submission = getCheckinResults()

        for results in submission.values {
            if let res = results as? [String: Any] {
                var removals = [[String: Any]]()

                if let message = res["messages"] as? [String: Any] {
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
                        for (key, _) in removal {
                            Log.debug("Removing message \(removal)")
                            var r = results as! [String: Any]
                            r.removeValue(forKey: key)
                        }
                    }
                }

            } else {
                continue
            }
        }
    }
}

func removeSkippedFacts() {
    var update = false
    var submission = getCheckinResults()

    let skipFacts = salPref("SkipFacts") as! [String]
    if !skipFacts.isEmpty {
        for (key, results) in submission {
            if let _ = results as? [String: Any] {
                var res = results as? [String: Any]
                var removals = [String]()

                if let facts = (res!["facts"] as? [String: Any]) {
                    for fact in facts.keys {
                        if skipFacts.contains(fact) {
                            removals.append(fact)
                        }
                    }
                }

                if !removals.isEmpty {
                    update = true
                    for removal in removals {
                        Log.debug("Removing message \(removal)")
                        res!.removeValue(forKey: removal)
                        submission.updateValue(res as Any, forKey: key)
                    }
                }
            }
        }
    }
    if update {
        saveResults(data: submission)
    }
}

func sendCheckin(report: [String: Any], client: SalClient) -> (responseString: String, httpResponse: HTTPURLResponse) {
    Log.debug("Sending report")

    let post = client.post(requestUrl: "checkin/", jsonData: report)
    client.submitRequest(method: "POST", request: post)

    let (res, response) = client.readResponse()

    return (res, response)
}

func sendInventory(serial: String, client: SalClient) {
    Log.info("Processing inventory...")
    let managedInstallDir = getAppPref(prefName: "ManagedInstallDir", domain: "ManagedInstalls")
    let inventoryPlist = (managedInstallDir! as! String) +  "/ApplicationInventory.plist"
    Log.debug("ApplicationInventory.plist Path: \(inventoryPlist)")
    
//    do {
//        let compressedData = try (yourData as NSData).compressed(using: .lzfse)
//        // use your compressed data
//    } catch {
//        print(error.localizedDescription)
//    }
    
    let inventoryHash = getHash(inputFile: inventoryPlist)
    Log.debug("inventory hash: \(inventoryHash)")
    let serverHash = ""
    
    let get = client.get(requestUrl: "inventory/hash/\(serial)/")
    client.submitRequest(method: "GET", request: get)
    let (res, response) = client.readResponse()
    
    if response.statusCode > 400 {
        Log.debug("Failed to get inventory hash: \(response.statusCode) \(response.allHeaderFields)")
        return
    }
    
    if response.statusCode == 200 {
        readBytesFromFile(filePath: inventoryPlist)
        if res != inventoryHash {
            Log.info("Inventory is out of date; submitting...")
//            let inventorySubmission = [
//                "serial": serial,
//
//            ]
        }
    }
    
    
}
