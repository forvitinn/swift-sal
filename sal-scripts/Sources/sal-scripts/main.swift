import Foundation
import ArgumentParser

let version = "0.0.1"

let checkinModules = gatherInfo()
print(dictToJson(dictItem: checkinModules))



