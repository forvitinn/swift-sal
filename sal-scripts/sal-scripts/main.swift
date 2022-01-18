//
//  main.swift
//  sal-scripts
//
//  Created by John Peterson on 1/14/22.
//

import Foundation

let version = "0.0.1"

initLogger()

let checkinModules = gatherInfo()
print(dictToJson(dictItem: checkinModules))
