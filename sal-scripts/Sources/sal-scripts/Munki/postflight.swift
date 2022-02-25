//
//  postflight.swift
//  ArgumentParser
//
//  Created by John Peterson on 2/22/22.
//

import Foundation
// https://stackoverflow.com/questions/65224939/how-to-check-if-a-url-is-valid-in-swift
extension URL {
    func isReachable(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: self)
        request.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: request) { _, response, _ in
            completion((response as? HTTPURLResponse)?.statusCode == 200)
        }.resume()
    }
}

let TOUCH_FILE_PATH = "/Users/Shared/.com.salopensource.sal.run"
let LAUNCHD = "com.salopensource.sal.runner"
let LAUNCHD_PATH = "/Library/LaunchDaemons/\(LAUNCHD).plist"
let SUBMIT_SCRIPT = "/usr/local/sal/bin/sal-submit"

func checkForErrors(report: [String: Any]) -> Bool {
    // Checks if the device was offline for last Munki run.
    let targetErrors = ["Could not retrieve managed install primary manifest."]

    let errors: Array = report["Errors"] as! [String]
    if errors == targetErrors {
        return true
    }
    return false
}

func checkServerConnection() -> Bool {
    let host = getAppPref(prefName: "SoftwareRepoURL", domain: "ManagedInstalls")
    let munkiHost = URL(string: host as! String)!
    var reachable = true
    munkiHost.isReachable { success in
        if success {
            reachable = true
        } else {
            reachable = false
        }
    }
    return reachable
}

func checkServerOnline() {
    // is the offline report pref true?
    let send = salPref("SendOfflineReport")
    if !(send as! String).boolValue {
        return
    }
    // read report
    let report = getManagedInstallReport()

    // check for errors and warnings
    if !checkForErrors(report: report as! [String: Any]) {
        setPref("LastRunWasOffline", false)
        return
    }

    // if they're there check is server is really offline
    if !checkServerConnection() {
        setPref("LastRunWasOffline", true)
        return
    }
    // If we get here, it's online
    setPref("LastRunWasOffline", false)
}

func writeTouchFile() {
    let url = URL(string: TOUCH_FILE_PATH)!
    if fileManager.fileExists(atPath: TOUCH_FILE_PATH) {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            Log.debug("could not remove \(TOUCH_FILE_PATH)")
        }
    } else {
        do {
            try "".write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Log.debug("could not create \(TOUCH_FILE_PATH)")
        }
    }
}

func ensureLDLoaded() {
    let (error, loadedLD) = exec(command: "/bin/launchctl", arguments: ["list"])
    if error != "" {
        Log.debug("error checking loaded Launch Daemons: \(error)")
        return
    }
    if !loadedLD.contains(LAUNCHD) {
        if fileManager.fileExists(atPath: LAUNCHD_PATH) {
            let (err, _) = exec(command: "/bin/launchctl", arguments: ["load", LAUNCHD_PATH])
            if err != "" {
                Log.debug("error loading \(LAUNCHD_PATH): \(err)")
            }
        }
    }
}

func munkiPostFlight() {
    checkServerOnline()
    writeTouchFile()
    ensureLDLoaded()
    // If the launchd isn't present, call the submit script old school
    if !fileManager.fileExists(atPath: LAUNCHD_PATH) {
        salSubmit()
    }
}
