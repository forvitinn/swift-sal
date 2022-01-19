//
//  Prefs.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import Foundation

let fileManager = FileManager.default

// MARK: borrowed from https://github.com/munki/munki/blob/main/code/apps/Managed%20Software%20Center/Managed%20Software%20Center/FoundationPlist.swift
enum FoundationPlistError: Error {
    case readError(description: String)
    case writeError(description: String)
}

func deserialize(_ data: Data?) throws -> Any? {
    if data != nil {
        do {
            let dataObject = try PropertyListSerialization.propertyList(
                from: data!,
                options: PropertyListSerialization.MutabilityOptions.mutableContainers,
                format: nil
            )
            return dataObject
        } catch {
            throw FoundationPlistError.readError(description: "\(error)")
        }
    }
    return nil
}

func pref(_ prefName: String, _ prefDomain: String) -> Any? {
    /* Return a preference. Since this uses CFPreferencesCopyAppValue,
     Preferences can be defined several places. Precedence is:
     - MCX
     - ~/Library/Preferences/ManagedInstalls.plist
     - /Library/Preferences/ManagedInstalls.plist
     - defaultPrefs defined here. */
    var value: Any? = "None"
    value = CFPreferencesCopyAppValue(prefName as CFString, prefDomain as CFString)
    if value == nil {
        Log.debug("cannot read preference key for: \(prefName)")
    }
    return value
}

func readPlist(_ filepath: String) throws -> Any? {
    return try deserialize(NSData(contentsOfFile: filepath) as Data?)
}

func readPlistFromString(_ stringData: String) throws -> Any? {
    return try deserialize(stringData.data(using: String.Encoding.utf8))
}

func reloadPrefs(bundleID: String) {
    /* Uses CFPreferencesAppSynchronize(BUNDLE_ID)
     to make sure we have the latest prefs. Call this
     if another process may have modified ManagedInstalls.plist,
     this needs to be run after returning from MunkiStatus */
    CFPreferencesAppSynchronize(bundleID as CFString)
}

func su_pref(_ prefName: String) -> Any? {
    // Return a com.apple.SoftwareUpdate preference.
    return CFPreferencesCopyValue(prefName as CFString,
                                  "com.apple.SoftwareUpdate" as CFString,
                                  kCFPreferencesAnyUser,
                                  kCFPreferencesCurrentHost)
}

func serialize(_ plist: Any) throws -> Data {
    do {
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: PropertyListSerialization.PropertyListFormat.xml,
            options: 0)
        return plistData
    } catch {
        throw FoundationPlistError.writeError(description: "\(error)")
    }
}

func writePlist(_ dataObject: Any, toFile filepath: String) throws {
    do {
        let data = try serialize(dataObject) as NSData
        if !(data.write(toFile: filepath, atomically: true)) {
            throw FoundationPlistError.writeError(description: "write failed")
        }
    } catch {
        throw FoundationPlistError.writeError(description: "\(error)")
    }
}
// MARK: end of munki help
func getPref(plistPath: String, plistKey: String) -> String {
    if fileManager.fileExists(atPath: plistPath) {
        let resultDictionary = NSDictionary(contentsOfFile: plistPath)
        guard let value = resultDictionary!.value(forKey: plistKey) else {
            return "Empty"
        }
        return value as! String
    } else {
        return ""
    }
}

func setPref(_ prefName: String,  _ prefValue: Any) {
     CFPreferencesSetValue(prefName as CFString, prefValue as! CFString, salPrefDomain as CFString, kCFPreferencesAnyUser, kCFPreferencesCurrentHost)
    reloadPrefs(bundleID: salPrefDomain)
}
