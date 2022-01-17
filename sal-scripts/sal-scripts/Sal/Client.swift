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
    let basic_timeout = [3.05, 4]
    let post_timeout = [3.05, 8]
        
    func createSession() {
        if (self._auth != nil) {
            print(0)
        }
        if (self._cert != nil) {
            print(1)
        }
        if (self._verify != nil) {
            print(2)
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
    
    func get(requestUrl: String) {
        let url = URL(string: buildUrl(url: requestUrl))
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"

    }
    
    func post(requestUrl: String) {
        let url = URL(string: buildUrl(url: requestUrl))
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"

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
        }
        task.resume()
    }
    
    func submitRequest(method: String, request: URLRequest) {
        let sessionConfig = URLSessionConfiguration.default
        if method == "GET" {
            sessionConfig.timeoutIntervalForRequest = basic_timeout[0]
            sessionConfig.timeoutIntervalForResource = basic_timeout[1]
        }
        if method == "POST" {
            sessionConfig.timeoutIntervalForRequest = post_timeout[0]
            sessionConfig.timeoutIntervalForResource = post_timeout[1]
        }
        
        var finished = false

        httpRequest(request: request, session: sessionConfig) {
            finished = true
        }

        while !finished {
            RunLoop.current.run(mode: .default, before: .distantFuture)
        }
    }
}

