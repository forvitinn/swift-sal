////
////  salCheckin.swift
////  sal-scripts
////
////  Created by John Peterson on 1/15/22.
////
//
//import Darwin
//import Foundation
//
//
//struct Sal {
//    func run() {
//        
//        var finished = false
//        
//        httpRequest {
//            finished = true
//        }
//        
//        while !finished {
//            RunLoop.current.run(mode: .default, before: .distantFuture)
//        }
//    }
//    

//
//    
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
//
//    // https://stackoverflow.com/questions/66979506/making-http-get-request-with-swift-5
//    func httpRequest(completion: @escaping () -> Void) {
////        let prefs = self.grabPrefs()
//        let salSubmission = self.gatherInfo()
//        let body = dictToJson(dictItem: salSubmission) as! String
//        
//        let headerValue = prefs["submissionKey"]!
//        let url = URL(string: prefs["submissionUrl"]!)
//        
//        var request = URLRequest(url: url!)
//        let requestBody = body.data(using: .utf8)
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = requestBody
//        request.httpMethod = "POST"
//        request.setValue(headerValue, forHTTPHeaderField: "Authorization")
//        
//        let task = URLSession.shared.dataTask(with: request) { data, _, error in
//            defer {
//                DispatchQueue.main.async {
//                    completion()
//                }
//            }
//    
//            guard
//                error == nil,
//                let data = data,
//                let response = String(data: data, encoding: .utf8)
//            else {
//                Log.error("error submitting results: \(String(describing: error))")
//                return
//            }
//    
//            Log.info("submission response: \(response)")
//        }
//        task.resume()
//    }
//}
