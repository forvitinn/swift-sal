//
//  salUtils.swift
//  sal-scripts
//
//  Created by John Peterson on 1/15/22.
//

import Foundation

let salPrefDomain = "com.github.salopensource.sal"

func setupSalClient() {
    let client = SalClient.init()
    
    let caCert = salPref("CACert")
    let clientCert = salPref("SSLClientCertificate")
    let certKey = salPref("SSLClientKey")
    
    let certArray = [caCert, clientCert, certKey]
    
    if let _ = certArray.first(where: {fileManager.fileExists(atPath: $0 as! String)}) {
        if !certArray.allSatisfy({ fileManager.fileExists(atPath: $0 as! String) }) {
            Log.warning("""
                        Argument warning! If using the `CACert`, `SSLClientCertificate`, or ",
                        "`SSLClientKey` prefs, they must all be either paths to cert files or the "
                        "common name of the certs to find in the keychain.
            """)
        }
        Log.debug("Using SalClient")
    } else {
        /*
         Assume that any passed certs are by CN since they don't
        exist as files anywhere.
        
         If we're going to use the keychain, we need to use a
        macsesh
        */
        Log.debug("Using MacKeychainClient")
    }
    
    if (caCert as! String) != "" {
        client.verify(path: (caCert as! String))
    }

    if (clientCert as! String) != "" {
        if (certKey as! String) != "" {
            client.cert(certificate: (clientCert as! String), key: (certKey as! String))
        }
        client.cert(certificate: (clientCert as! String), key: nil)
    }
    
    let basicAuth = salPref("BasicAuth")
    if (basicAuth as! String) != "" {
        let key = salPref("key")
        client.auth(creds: ["sal", (key as! String)])
    }
    
    client.baseUrl(url: (salPref("ServerURL") as! String))
}

func salPref(_ prefName: String) -> Any {
    let defaultPrefs = [
        "ServerURL": "http://sal",
        "osquery_launchd": "com.facebook.osqueryd.plist",
        "SkipFacts": [],
        "SyncScripts": true,
        "BasicAuth": true,
        "GetGrains": false,
        "GetOhai": false,
        "LastRunWasOffline": false,
        "SendOfflineReport": false,
    ] as [String : Any]
    
    let prefs = [
        "ServerURL",
        "key",
        "BasicAuth",
        "SyncScripts",
        "SkipFacts",
        "CACert",
        "SendOfflineReport",
        "SSLClientCertificate",
        "SSLClientKey",
        "MessageBlacklistPatterns",
    ]
    var prefVal: Any = ""
    
    for prefName in prefs {
        prefVal = pref(prefName, salPrefDomain) ?? "None"
        if (prefVal as! String) == "None" {
            if let _ = defaultPrefs[prefName] {
                // If we got here, the pref value was either set to None or never
                // set, AND the default was also None. Fall back to auto prefs.
                prefVal = defaultPrefs[prefName] as Any
                /*
                Sets a Sal preference.
                The preference file on disk is located at
                /Library/Preferences/com.github.salopensource.sal.plist.  This should
                normally be used only for 'bookkeeping' values; values that control
                the behavior of munki may be overridden elsewhere (by MCX, for
                example)
                */
                setPref(prefName, prefVal as Any)
            }
        }
    }
    return prefVal
}

func unobjctify(_ item: Any?) -> Any? {
    /*
     this serves a far small smaller purpose than the unobjctify function
     in the python client. the main type that trips this up is the NSTaggedDate / NSDate
     types. those are largely handled in serializing the data when it is gathered.
     leaving this as a fail safe to catch custome data?
     */
   
    switch item {
    case is Bool:
        // pythonify the bool?
        Log.debug("\(String(describing: item)) is a Double")
        return item
    case is String:
        Log.debug("\(String(describing: item)) is an String")
        return item
    case is Int:
        Log.debug("\(String(describing: item)) is an Int")
        return item
    case is Double:
        Log.debug("\(String(describing: item)) is a Double")
        return item
    case is NSDate:
        Log.debug("\(String(describing: item)) is NSDate. Trying to convert.")
        return (item as! String)
    case is Dictionary<String, Any>:
        Log.debug("\(String(describing: item)) is a Dictionary")
        for key in (item as! [String:Any]).keys {
            return unobjctify(key)
        }
        for value in (item as! [String:Any]).values {
            return unobjctify(value)
        }
    default:
        Log.debug("\(String(describing: item)) is unchecked type")
        return item
    }
    return item
}

func scriptIsRunning(scriptName: String) -> Bool {
    let (error, output) = exec(command: "/bin/ps", arguments: ["-eo", "command="])
    if error != "" {
        Log.debug("error checking to see if \(scriptName) is running")
        return false
    }
    let lines = output.components(separatedBy: "\n")
    for line in lines {
        let part = line.components(separatedBy: " ")
        if (part[0].contains("/MacOS/Python") || part[0].contains("python")) {
            if part.count > 1 {
                if part[1].contains(scriptName) {
                    return true
                }
            }
        }
    }
    return false
}

func runScripts(directory: String, scriptArgs: [String], error: Bool = false) -> [String] {
    var results = [String]()
    var scripts = [Any]()
    let skipNames = ["__pycache__"]
    
    let files = fileManager.enumerator(atPath: directory)
    while let file = files?.nextObject() {
        if !skipNames.contains(file as! String) {
            scripts.append(file)
        }
    }
    
    for script in scripts {
        if !fileManager.isExecutableFile(atPath: script as! String) {
            results.append("\(script) is not executable or has bad permissions")
            continue
        }

        let (err, _) = exec(command: script as! String, arguments: scriptArgs)
        
        if err != "" {
            let errorMessage = "error running \(script): \(err)"
            if !error {
                results.append(errorMessage)
            } else {
                Log.error(errorMessage)
            }
        }
        
        results.append("\(script) ran successfully")
    }
    
    return results
}


func waitForScript(scriptName: String, repeatCount:Int = 3, pause:UInt32 = 1) -> Bool {
    var count = 0
    while count < repeatCount {
        if scriptIsRunning(scriptName: scriptName) {
            sleep(pause)
            count += 1
        } else {
            return false
        }
    }
    return true
}
