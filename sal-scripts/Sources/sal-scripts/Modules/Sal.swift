//
//  Sal.swift
//  sal-scripts
//
//  Created by John Peterson on 2/21/22.
//

import Foundation

let salVersion = "1.1.0"

func SalReport() -> [String: Any] {
    let salSubmission = [
        "extra_data": [
            "sal_version": salVersion,
            "key": salPref("key"),
        ],
        "facts": ["checkin_module_version": salVersion],
    ]

    return ["Sal": salSubmission]
}
