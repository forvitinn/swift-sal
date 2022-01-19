//
//  salCheckin.swift
//  sal-scripts
//
//  Created by John Peterson on 1/15/22.
//

import Foundation
  
func gatherInfo() -> [String:Any] {
    var salSubmission = [String: Any]()
    
    let machine = MachineReport()
    let munki = MunkiReport()
    let profiles = ProfileReport()
    let sus = SoftwareUpdateReport()
    
    // probably a better way to do this.
    for item in [munki, profiles, sus, machine] {
        salSubmission.merge(dict: item)
    }
    
    return salSubmission
}
