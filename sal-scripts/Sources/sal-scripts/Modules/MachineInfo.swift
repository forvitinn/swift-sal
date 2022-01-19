//
//  MachineInfo.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import Foundation
import IOKit

func MachineReport() -> [String: Any] {
    var machineResults = [String: Any]()
    var extras = [String: Any]()

    extras = processSystemProfile()
    extras["hostname"] = Host.current().localizedName
    extras["os_family"] = "Darwin"
    extras["console_user"] = getSystemConsoleUsername()

    machineResults["facts"] = ["checkin_module_version": version]
    machineResults.updateValue(extras, forKey: "extra_data")

    return ["Machine": machineResults]
}

func processSystemProfile() -> [String: Any] {
    var machineResults = [String: Any]()

    machineResults["serial"] = getSerialNumber()
    machineResults["operating_system"] = getMajorOSVersion()
    machineResults["machine_model"] = getMacModel()!
    machineResults["machine_model_friendly"] = getFriendlyModel()
    machineResults["cpu_type"] = getCPUTypeString()
    machineResults["memory"] = getMachineMemoryString(memFormat: "GB", includeUnit: true)
    machineResults["memory_kb"] = getMachineMemoryString(memFormat: "KB", includeUnit: false)

    let diskUsage = getDeviceDiskUsage()

    machineResults["hd_space"] = diskUsage["available"]
    machineResults["hd_total"] = diskUsage["total"]
    machineResults["hd_percent"] = Int(CGFloat(Double(diskUsage["available"]!) / Double(diskUsage["total"]!) - 1) * 100)

    return machineResults
}
