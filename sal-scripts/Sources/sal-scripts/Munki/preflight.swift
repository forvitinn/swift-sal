//
//  preflight.swift
//  ArgumentParser
//
//  Created by John Peterson on 2/22/22.
//

import Foundation

let ExternalScriptsDir = "/usr/local/sal/external_scripts"

func munkiPreFlight() {
//    let client = setupSalClient()

    let sync = salPref("SyncScripts")
    if (sync as! String).boolValue {
        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: ExternalScriptsDir, isDirectory: &isDir) {
            do {
                try fileManager.createDirectory(atPath: ExternalScriptsDir, withIntermediateDirectories: true, attributes: [:])
            } catch {
                Log.debug("could not create \(ExternalScriptsDir): \(error)")
            }
        }

        let (err, serverScripts) = getCheckSums()
        if err != "" {
            Log.debug("error getting checksums: \(err)")
            return
        }
        createDirs(serverScripts: serverScripts)
        downloadScripts(serverScripts: serverScripts)
        cleanUpOldScripts(serverScripts: serverScripts)
        removeEmptyFolders(path: ExternalScriptsDir)
    }
}

func getCheckSums() -> (error: String, checkSums: [[String: Any]]) {
    /*
     Downloads the checksum of existing scripts.
     Returns:
         A dict with the script name, plugin name and hash of the script
         or None if no external scripts are used.
     */
    var checkSums = [[String: Any]]()
    let client = setupSalClient()
    let post = client.post(requestUrl: "preflight-v2/", jsonData: ["os_family": "Darwin"])
    client.submitRequest(method: "POST", request: post)

    let (res, response) = client.readResponse()
    if response.statusCode > 400 {
        Log.debug("Request failed with HTTP: \(response.statusCode)")
        return ("request failed", checkSums)
    }
    checkSums = convertToListOfDictionary(text: res)!
    return ("", checkSums)
}

func createDirs(serverScripts: [[String: Any]]) {
    /*
     Creates any directories needed for external scripts
     Directories are named after the plugin.
      */
    for item in serverScripts {
        let pluginDir = ExternalScriptsDir + "/" + (item["plugin"] as! String)
        do {
            try fileManager.createDirectory(atPath: pluginDir, withIntermediateDirectories: true, attributes: [:])
        } catch {
            Log.debug("Could not create plugin \(pluginDir): \(error)")
        }
    }
}

func downloadScripts(serverScripts: [[String: Any]]) {
    // Checksum local scripts and if no matches, download.
    for item in serverScripts {
        var downloadRequired = false
        let targetScript = ExternalScriptsDir + "/" + (item["plugin"] as! String) + "/" + (item["filename"] as! String)
        if !fileManager.fileExists(atPath: targetScript) {
            downloadRequired = true
        } else {
            let localHash = getHash(inputFile: targetScript)
            if localHash != (item["hash"] as! String) {
                downloadRequired = true
            }
        }

        if downloadRequired {
            Log.debug("downloading \(String(describing: item["filename"]!))")
            downloadWriteScript(serverScript: item)
        }
    }
}

func downloadWriteScript(serverScript: [String: Any]) {
    // Gets script from the server and makes it executable.
    let client = setupSalClient()
    let scriptURL = "preflight-v2/get-script/\(String(describing: serverScript["plugin"]!))/\(String(describing: serverScript["filename"]!))/"
    let get = client.get(requestUrl: scriptURL)
    client.submitRequest(method: "GET", request: get)

    let (res, response) = client.readResponse()
    if response.statusCode > 400 {
        Log.debug("Error received downloading script: \(response.statusCode)")
        return
    }

    let resData = convertToListOfDictionary(text: res)
    let scriptPath = ExternalScriptsDir + "/" + (serverScript["plugin"] as! String) + "/" + (serverScript["filename"] as! String)
    let url = URL(fileURLWithPath: scriptPath)

    if !fileManager.fileExists(atPath: scriptPath) {
        do {
            try (resData![0]["content"] as! String).write(to: url, atomically: true, encoding: .utf8)
            do {
                var attributes = [FileAttributeKey: Any]()
                attributes[.posixPermissions] = 0o755

                try fileManager.setAttributes(attributes, ofItemAtPath: scriptPath)
            } catch {
                Log.debug("could not update permissions on \(scriptPath): \(error)")
            }
        } catch {
            Log.debug("could not create \(scriptPath): \(error)")
        }
    }
}

func cleanUpOldScripts(serverScripts: [[String: Any]]) {
    // Finds and removes scripts on disk that aren't needed anymore.
    if serverScripts.isEmpty {
        do {
            try fileManager.removeItem(atPath: ExternalScriptsDir)
        } catch {
            Log.debug("could not remove \(ExternalScriptsDir): \(error)")
        }
    } else {
        var keep = [String]()
        for script in serverScripts {
            let scriptPath = ExternalScriptsDir + "/" + (script["plugin"] as! String) + "/" + (script["filename"] as! String)
            keep.append(scriptPath)
        }
        do {
            let url = URL(fileURLWithPath: ExternalScriptsDir)

            let subDirs = try url.subDirectories()

            for folder in subDirs {
                if folder.lastPathComponent.starts(with: ".") {
                    continue
                }
                let scripts = try FileManager.default.contentsOfDirectory(at: folder.absoluteURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

                for script in scripts {
                    if !keep.contains(script.path) {
                        do {
                            try fileManager.removeItem(atPath: script.path)
                        } catch {
                            Log.debug("could not remove item \(script.path): \(error)")
                        }
                    }
                }
            }

        } catch {
            Log.debug("error running script: \(error)")
        }
    }
}

func removeEmptyFolders(path _: String) {
    // Function to remove empty folders.
    do {
        let url = URL(fileURLWithPath: ExternalScriptsDir)

        let subDirs = try url.subDirectories()

        for folder in subDirs {
            do {
                try fileManager.removeItem(atPath: folder.path)
            } catch {
                Log.debug("could not remove folder: \(error)")
            }
        }
    } catch {
        Log.debug("could not enumerate subdirectories: \(error)")
    }
}
