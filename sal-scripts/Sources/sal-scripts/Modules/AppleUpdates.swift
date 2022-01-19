//
//  AppleUpdates.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import Foundation

func SoftwareUpdateReport() -> [String: Any] {
    var salSubmission = [String: Any]()
    let susReport = getSusInstallReport()
    let pending = getPending()

    let facts = pending.merging(susReport) { current, _ in current }
    salSubmission["facts"] = facts
    salSubmission["update_history"] = [Any]()

    return ["Apple Software Update": salSubmission]
}

func getSusInstallReport() -> [String: Any] {
    var returnReport = [String: Any]()
    var installReport = [[String: Any]]()

    do {
        installReport = try readPlist("/Library/Receipts/InstallHistory.plist") as! [[String: Any]]
    } catch {
        Log.debug("error reading /Library/Receipts/InstallHistory.plist")
        return returnReport
    }
    for item in installReport {
        if item["processName"] as! String == "softwareupdated" {
            let date = item["date"]!
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateString = df.string(from: date as! Date)
            returnReport[item["displayName"] as! String] = [
                "date_managed": dateString,
                "status": "PRESENT",
                "data": [
                    "type": "Apple SUS Install",
                    "version": (item["displayVersion"] as! String).trimmingCharacters(in: .whitespacesAndNewlines),
                ],
            ]
        }
    }

    return returnReport
}

func getPending() -> [String: Any] {
    // https://github.com/munki/munki/blob/main/code/apps/Managed%20Software%20Center/Managed%20Software%20Center/appleupdates.swift
    var pendingReport = [String: Any]()

    if let recommendedUpdates = su_pref("RecommendedUpdates") as? [[String: Any]] {
        for update in recommendedUpdates {
            pendingReport[update["Display Name"] as! String] = [
                "date_managed": getUTCISOTime(date: Date()),
                "status": "PENDING",
                "data": [
                    "version": update["Display Version"] as! String,
                    "recommended": "TRUE",
                    "product_key": update["Product Key"] as! String,
                ],
            ]
        }
    } else {
        return pendingReport
    }

    return pendingReport
}
