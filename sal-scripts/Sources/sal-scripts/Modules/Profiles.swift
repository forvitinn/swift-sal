//
//  Profiles.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import Foundation

func ProfileReport() -> [String: Any] {
    let p = getProfiles()
    let profiles = p as! [String: Any]

    var submission = [String: Any]()
    submission["facts"] = ["checkin_module_version": version]
    submission["managed_items"] = [String: Any]()

    var submissionUpdate = submission["managed_items"] as! [String: Any]

    if let profileInfo = profiles["_computerlevel"] as? [[String: Any]] {
        for profile in profileInfo {
            let name = profile["ProfileDisplayName"] ?? ""

            var submissionItem = [String: Any]()
            submissionItem["name"] = name
            submissionItem["date_managed"] = profile["ProfileInstallDate"]
            submissionItem["status"] = "PRESENT"

            var data = [String: Any]()

            let profileItems = profile["ProfileItems"] as? [[String: Any]] ?? []

            var count = 0
            for (c, payload) in profileItems.enumerated() {
                count += c + 1
                data["payload \(count)"] = payload
            }

            var payloadTypes = [String]()
            for p in profileItems {
                payloadTypes.append(p["PayloadType"] as! String)
            }

            data["payload_types"] = payloadTypes
            data["profile_description"] = profile["ProfileDescription"] ?? "None"
            data["identifier"] = profile["ProfileIdentifier"]
            data["organization"] = profile["ProfileOrganization"] ?? "None"
            data["uuid"] = profile["ProfileUUID"]
            data["verification_state"] = profile["ProfileVerificationState"] ?? ""
            submissionItem["data"] = data
            submissionUpdate.updateValue(submissionItem, forKey: name as! String)
        }
    }
    submission["managed_items"] = submissionUpdate

    return ["Profiles": submission]
}

func getProfiles() -> NSDictionary? {
    let tempDirectory = NSTemporaryDirectory()
    let profileOut = tempDirectory + "profiles.plist"

    let task = Process()
    task.launchPath = "/usr/bin/profiles"
    task.arguments = ["-C", "-o", profileOut]

    // this will output a count of installed profiles when ran
    // so we silence the stdout by capturing it
    let outputPipe = Pipe()
    task.standardOutput = outputPipe

    do {
        try task.run()
    } catch {
        Log.debug("Error listing installed profiles")
    }

    task.waitUntilExit()

    if !FileManager.default.fileExists(atPath: profileOut) {
        Log.debug("Could not read profiles output")
        return [:]
    }

    let profileReport = NSDictionary(contentsOfFile: profileOut)
    do {
        try FileManager.default.removeItem(atPath: profileOut)
    } catch {
        Log.debug("Error removing temporary profile directory")
    }

    return profileReport
}
