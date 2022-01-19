//
//  Munki.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import AppKit
import Foundation
import IOKit
import SystemConfiguration

let BUNDLE_ID = "ManagedInstalls" as CFString
var munkiPref = "/Library/Preferences/ManagedInstalls.plist"

func MunkiReport() -> [String: Any] {
    let date = Date()
    let munkiReport = getManagedInstallReport()
    var munkiSubmission: Dictionary = [String: Any]()

    munkiSubmission["extra_data"] = [
        "munki_version": munkiReport.value(forKeyPath: "MachineInfo.munki_version") ?? "",
        "manifest": munkiReport.value(forKeyPath: "ManifestName") ?? "",
        "runtype": munkiReport.value(forKeyPath: "RunType") ?? "custom",
    ]

    let startTime = munkiReport.value(forKeyPath: "StartTime") ?? ""
    let endTime = munkiReport.value(forKeyPath: "EndTime") ?? ""

    munkiSubmission["facts"] = [
        "checkin_module_version": version,
        "RunType": munkiReport.value(forKeyPath: "RunType") ?? "",
        "StartTime": startTime as! String,
        "EndTime": endTime as! String,
    ]

    if let val = munkiReport["Conditions"] {
        let conditionDict: Dictionary = val as! [String: Any]
        var conditionVals: Dictionary = munkiSubmission["facts"] as! [String: Any]

        for (key, value) in conditionDict {
            var updateVal: Any
            if let _ = value as? [String] {
                // obj is a string array. Do something with stringArray
                let valString = value as! [String]
                updateVal = valString.joined(separator: "")
            } else {
                updateVal = value
            }

            conditionVals.updateValue(updateVal, forKey: key)
        }

        let replaceDate = conditionVals["date"] as! Date
        conditionVals["date"] = getUTCISOTime(date: discardTimeZoneFromDate(_: replaceDate))
        munkiSubmission["facts"] = conditionVals
    }

    var messageUpdate = [Any]()
    for key in ["Errors", "Warnings"] {
        var messageDict = [String: Any]()

        let messageArray: Array = munkiReport[key] as! [String]
        let msg = messageArray.joined(separator: "")

        let updateVal = [
            "message_type": key.uppercased().dropLast(),
            "text": msg,
        ] as [String: Any]

        messageDict.updateValue(updateVal, forKey: key)
        messageUpdate.append(messageDict)
    }

    munkiSubmission["messages"] = messageUpdate
    munkiSubmission["managed_items"] = [String: Any]()

    var updateManagedItems: Dictionary = munkiSubmission["managed_items"] as! [String: Any]

    let optionalManifest = getOptionalManifest()
    let now = getUTCISOTime(date: date)

    if let managedVal = munkiReport["ManagedInstalls"] {
        for i in managedVal as! [[String: Any]] {
            var item = i
            var appStatus = "ABSENT"
            var versionKey = "version_to_install"

            if item["installed"] as! Int == 1 {
                appStatus = "PRESENT"
                versionKey = "installed_version"
            }

            var selfServe = "False"
            let name = "\(item["name"] as! String) \(item[versionKey] as! String)"

            item.removeValue(forKey: "name")
            item.removeValue(forKey: "installed")

            if (optionalManifest["managed_installs"] as! Array).contains(name) {
                selfServe = "True"
            }
            item["self_serve"] = selfServe
            item["type"] = "ManagedInstalls"

            let submissionItem = [
                "data": item,
                "date_managed": now,
                "status": appStatus,
                "name": name,
            ] as [String: Any]
            updateManagedItems.updateValue(submissionItem, forKey: name)
        }
        munkiSubmission["managed_items"] = updateManagedItems
    }

    if let managedUninstallVal = munkiReport["managed_uninstalls_list"] {
        for item in managedUninstallVal as! [String] {
            var selfServe = "False"
            if let _ = optionalManifest["managed_uninstalls"] {
                let uninstallApps: Array = optionalManifest["managed_uninstalls"] as! [String]

                if uninstallApps.contains(item) {
                    selfServe = "TRUE"
                }
                let submissionItem = ["date_managed": now,
                                      "status": "ABSENT",
                                      "data": ["self_serve": selfServe, "type": "ManagedUninstalls"]] as [String: Any]

                munkiSubmission.updateValue(submissionItem, forKey: item)
            }
        }

        // Process InstallResults and RemovalResults into update history
        for reportKey in ["InstallResults", "RemovalResults"] {
            if let _ = munkiReport[reportKey] {
                let reportArray = munkiReport[reportKey] as! [Any]

                for item in reportArray {
                    var i = item as! [String: Any]
                    // Skip Apple software update items.
                    if let _ = i["applesus"] {
                        continue
                    }
                    // Construct key; we pop the name off because we don't need
                    // to submit it again when we stuff `item` into `data`.
                    let name = "\(i["name"] as! String) \(i["version"] as! String)"

                    var submissionItem = [String: Any]()
                    if let managedItems = munkiSubmission["managed_items"] as? [String: Any] {
                        submissionItem = managedItems[name] as! [String: Any]
                    } else {
                        submissionItem = ["name": name]
                    }
                    i.removeValue(forKey: "name")

                    if let s = i["status"] {
                        // Something went wrong, so change the status.
                        if s as! Int != 0 {
                            submissionItem["status"] = "ERROR"
                        }
                    } else {
                        submissionItem["status"] = "ERROR"
                    }

                    if let _ = submissionItem["data"] {
                        submissionItem.updateValue(item, forKey: "data")
                    } else {
                        submissionItem["data"] = item
                    }

                    var dataType: String
                    if let _ = (submissionItem["data"] as! [String: Any])["type"] {
                        continue
                    } else {
                        if reportKey == "InstallResults" {
                            dataType = "ManagedInstalls"
                        } else {
                            dataType = "ManagedUninstalls"
                        }
                        var keyUpdate = submissionItem["data"] as! [String: Any]
                        keyUpdate.updateValue(dataType, forKey: "type")

                        submissionItem.updateValue(keyUpdate, forKey: "data")
                    }

                    let itemTime = stringFromDate(getUTCISOTimeFromString(dateString: i["time"] as! String))
                    submissionItem["date_managed"] = itemTime

                    var submissionUpdate = munkiSubmission["managed_items"] as! [String: Any]
                    submissionUpdate.updateValue(submissionItem, forKey: name)
                    munkiSubmission.updateValue(submissionUpdate, forKey: "managed_items")
                }
            }
        }
    }

    return ["munki": munkiSubmission]
}

func getManagedInstallReport() -> NSDictionary {
    let prefLocation = getPref(plistPath: munkiPref, plistKey: "ManagedInstallDir")

    let managedInstallReport = prefLocation + "/ManagedInstallReport.plist"

    if !FileManager.default.fileExists(atPath: managedInstallReport) {
        Log.debug("Could not read munki ManagedInstallReport")
    }

    let munkiReport = NSDictionary(contentsOfFile: managedInstallReport)
    return munkiReport!
}

func getOptionalManifest() -> NSDictionary {
    let prefLocation = getPref(plistPath: munkiPref, plistKey: "ManagedInstallDir")

    let managedInstallReport = prefLocation + "/manifests/SelfServeManifest"

    if !FileManager.default.fileExists(atPath: managedInstallReport) {
        Log.debug("Could not read munki SelfServeManifest")
        return NSDictionary()
    }

    let munkiReport = NSDictionary(contentsOfFile: managedInstallReport)
    return munkiReport!
}
