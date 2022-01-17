//
//  Machine.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import Foundation
import SystemConfiguration

// MARK: borrowed from https://github.com/macadmins/nudge
extension FixedWidthInteger {
    // https://stackoverflow.com/a/63539782
    var byteWidth: Int {
        return bitWidth / UInt8.bitWidth
    }

    static var byteWidth: Int {
        return Self.bitWidth / UInt8.bitWidth
    }
}

func getCPUTypeInt() -> Int {
    // https://stackoverflow.com/a/63539782
    var cputype = UInt32(0)
    var size = cputype.byteWidth
    let result = sysctlbyname("hw.cputype", &cputype, &size, nil, 0)
    if result == -1 {
        if errno == ENOENT {
            return 0
        }
        return -1
    }
    return Int(cputype)
}

func getCPUTypeString() -> String {
    // https://stackoverflow.com/a/63539782
    let type: Int = getCPUTypeInt()
    if type == -1 {
        return "error in CPU type"
    }

    let cpu_arch = type & 0xFF // mask for architecture bits
    if cpu_arch == cpu_type_t(7) {
        //Log.debug("CPU Type is Intel")
        return "Intel"
    }
    if cpu_arch == cpu_type_t(12) {
        //Log.debug("CPU Type is Apple Silicon")
        return "Apple Silicon"
    }
    Log.error("Unknown CPU Type")

    return "unknown"
}

func getMajorOSVersion() -> Int {
    let MajorOSVersion = ProcessInfo().operatingSystemVersion.majorVersion

    return MajorOSVersion
}

func getMinorOSVersion() -> Int {
    let MinorOSVersion = ProcessInfo().operatingSystemVersion.minorVersion

    return MinorOSVersion
}

func getPatchOSVersion() -> Int {
    let PatchOSVersion = ProcessInfo().operatingSystemVersion.patchVersion
    return PatchOSVersion
}

func getSerialNumber() -> String {
    var serialNumber: String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

        guard platformExpert > 0 else {
            return nil
        }

        guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
            return nil
        }

        IOObjectRelease(platformExpert)

        return serialNumber
    }

    return serialNumber ?? "0"
}

func getSystemConsoleUsername() -> String {
    // https://gist.github.com/joncardasis/2c46c062f8450b96bb1e571950b26bf7
    var uid: uid_t = 0
    var gid: gid_t = 0
    let SystemConsoleUsername = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) as String? ?? ""

    return SystemConsoleUsername
}

// MARK: General Machine details
func getFriendlyModel() -> String {
    let (err, res) = exec(command: "/usr/sbin/ioreg", arguments: ["-arc", "IOPlatformDevice", "-k", "product-name"])

    if res == "" {
        var results = [String: Any]()
        //Log.info("Using ioreg didnt work. Trying one more time.")
        let path = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Preferences/com.apple.SystemProfiler.plist")

        if FileManager.default.fileExists(atPath: path.path) {
            results = NSDictionary(contentsOf: path) as! [String: Any]
            if (results["CPU Names"] as! [String: Any]).count != 1 {
                Log.error("There should only be one model here. Cant reliably return info.")
                return ""
            }
            let model = Array(results["CPU Names"] as! [String: Any])[0].value

            return model as! String
        } else {
            Log.error("Could not read com.apple.SystemProfier.plist")
            return ""
        }
    }

    if err != "" {
        Log.error("Could not grab friendly model: \(err)")
        return ""
    }

    let ioregInfo = try! readPlistFromString(res) as! [[String: Any]]
    let friendlyModel = String(data: ioregInfo[0]["product-name"]! as! Data, encoding: .utf8)
    return friendlyModel!.trimmingCharacters(in: .whitespacesNewlinesAndNulls)
}

func getMacModel() -> String? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                              IOServiceMatching("IOPlatformExpertDevice"))
    var modelIdentifier: String?

    if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
        if let modelIdentifierCString = String(data: modelData, encoding: .utf8)?.cString(using: .utf8) {
            modelIdentifier = String(cString: modelIdentifierCString)
        }
    }

    IOObjectRelease(service)
    return modelIdentifier
}

func getMachineMemoryString(memFormat: String, includeUnit: Bool) -> String {
    var mem: Int
    let physicalMemory = ProcessInfo.processInfo.physicalMemory

    switch memFormat {
    case "KB":
        mem = Int(Double(physicalMemory) / 1024.0)
    case "MB":
        mem = Int(Double(physicalMemory) / (1024.0 * 1024.0))
    case "GB":
        mem = Int(Double(physicalMemory) / (1024.0 * 1024.0 * 1024.0))
    default:
        return ""
    }

    if !includeUnit {
        return "\(mem)"
    }
    return "\(mem)\(memFormat)"
}

func getDeviceDiskUsage() -> [String: Int] {
    // https://developer.apple.com/documentation/foundation/urlresourcekey/checking_volume_storage_capacity
    let fileURL = URL(fileURLWithPath: "/")
    do {
        let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        let capacity = values.volumeAvailableCapacityForImportantUsage
        let available = values.volumeTotalCapacity

        return ["total": Int(capacity!), "available": available!]
    } catch {
        Log.error("Error retrieving capacity: \(error.localizedDescription)")
        return [String: Int]()
    }
}
