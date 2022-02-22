//
//  Client.swift
//  sal-scripts
//
//  Created by John Peterson on 1/15/22.
//

import Foundation


class SalClient {
    var _base_url:String = ""
    var _auth: (Any)? = nil
    var _cert: (Any)? = nil
    var _verify: (Any)? = nil
    var sesh = URLSessionConfiguration.default
    let basic_timeout = [3.05, 4]
    let post_timeout = [3.05, 8]
    
        
    func createSession() {
        if (self._auth != nil) {
            let authData = ((self._auth as! Array)[0] + ":" + (self._auth as! Array)[1]).data(using: .utf8)!.base64EncodedString()
            self.sesh.httpAdditionalHeaders = [
                "Content-Type": "application/json; charset=utf-8",
                "Accept": "application/json; charset=utf-8",
                "Authorization": "Basic \(authData)"
            ]
        }
        if (self._cert != nil) {
            Log.debug("build me")
        }
        if (self._verify != nil) {
            Log.debug("build me")
        }
    }
    
    func auth(creds: [String]) {
        self._auth = creds
        self.createSession()
    }
    
    func baseUrl(url: String) {
        if url.hasSuffix("/") {
            self._base_url = String(url.dropLast())
        } else {
            self._base_url = url
        }
    }
    
    func cert(certificate: String, key: String?) {
        if key != nil {
            self._cert = [certificate, key]
        } else {
            self._cert = certificate
        }
        self.createSession()
    }
    
    func verify(path: String) {
        self._verify = path
        self.createSession()
    }
    
    func buildUrl(url: String) -> String {
        var endPoint: String = ""
        if url.hasPrefix("/") {
            endPoint = String(url.dropFirst())
        }
        if url.hasSuffix("/") {
            endPoint = String(url.dropLast())
        }
    
        return self._base_url + "/" + endPoint + "/"
    }
    
    func get(requestUrl: String) -> URLRequest {
        let url = URL(string: buildUrl(url: requestUrl))
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"

        return request
    }
    
    func post(requestUrl: String, jsonData: [String:Any]) -> URLRequest {
        let url = URL(string: buildUrl(url: requestUrl))
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let json = try? JSONSerialization.data(withJSONObject: jsonData.compactMapValues { $0 })

        request.httpBody = json
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")


        return request
    }
        
    func httpRequest(request: URLRequest, session: URLSessionConfiguration, completion: @escaping () -> Void) {
        let task = URLSession(configuration: session).dataTask(with: request) { data, _, error in
            defer {
                DispatchQueue.main.async {
                    completion()
                }
            }

            guard
                error == nil,
                let data = data,
                let response = String(data: data, encoding: .utf8)
                    
            else {
                Log.error("error submitting results: \(String(describing: error))")
                return
            }
            Log.info("submission response: \(response)")
            print(response.statusCode)
            
        }
        task.resume()
    }
    
    func submitRequest(method: String, request: URLRequest) {
        if method == "GET" {
            self.sesh.timeoutIntervalForRequest = basic_timeout[0]
            self.sesh.timeoutIntervalForResource = basic_timeout[1]
        }
        if method == "POST" {
            self.sesh.timeoutIntervalForRequest = post_timeout[0]
            self.sesh.timeoutIntervalForResource = post_timeout[1]
        }

        var finished = false

        httpRequest(request: request, session: self.sesh) {
            finished = true
        }

        while !finished {
            RunLoop.current.run(mode: .default, before: .distantFuture)
        }
    }
}

