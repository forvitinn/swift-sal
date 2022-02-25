//
//  Client.swift
//  sal-scripts
//
//  Created by John Peterson on 1/15/22.
//

import Foundation

class SalClient {
    var _base_url: String = ""
    var _auth: Any?
    var _cert: Any?
    var _verify: Any?

    var httpResponse = HTTPURLResponse()
    var responseString: String = ""
    var sesh = URLSessionConfiguration.default

    let basic_timeout = [3.05, 4]
    let post_timeout = [3.05, 8]

    func createSession() {
        if _auth != nil {
            let authData = ((_auth as! Array)[0] + ":" + (_auth as! Array)[1]).data(using: .utf8)!.base64EncodedString()
            sesh.httpAdditionalHeaders = [
                "Content-Type": "application/json; charset=utf-8",
                "Accept": "application/json; charset=utf-8",
                "Authorization": "Basic \(authData)",
            ]
        }
        if _cert != nil {
            Log.debug("build me")
        }
        if _verify != nil {
            Log.debug("build me")
        }
    }

    func auth(creds: [String]) {
        _auth = creds
        createSession()
    }

    func baseUrl(url: String) {
        if url.hasSuffix("/") {
            _base_url = String(url.dropLast())
        } else {
            _base_url = url
        }
    }

    func cert(certificate: String, key: String?) {
        if key != nil {
            _cert = [certificate, key]
        } else {
            _cert = certificate
        }
        createSession()
    }

    func readResponse() -> (responseString: String, httpResponse: HTTPURLResponse) {
        let resStr = responseString
        let httpRes = httpResponse
        responseString = ""
        httpResponse = HTTPURLResponse()

        return (resStr, httpRes)
    }

    func verify(path: String) {
        _verify = path
        createSession()
    }

    func buildUrl(url: String) -> String {
        var endPoint = ""
        if url.hasPrefix("/") {
            endPoint = String(url.dropFirst())
        }
        if url.hasSuffix("/") {
            endPoint = String(url.dropLast())
        }

        return _base_url + "/" + endPoint + "/"
    }

    func get(requestUrl: String) -> URLRequest {
        let url = URL(string: buildUrl(url: requestUrl))
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"

        return request
    }

    func post(requestUrl: String, jsonData: [String: Any]) -> URLRequest {
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
        let task = URLSession(configuration: session).dataTask(with: request) { data, response, error in
            defer {
                DispatchQueue.main.async {
                    completion()
                }
            }

            guard
                error == nil,
                let data = data,
                let res = String(data: data, encoding: .utf8),
                let response = response as? HTTPURLResponse
            else {
                Log.error("error submitting results: \(String(describing: error))")
                return
            }
            self.httpResponse = response
            self.responseString = res
        }
        task.resume()
    }

    func submitRequest(method: String, request: URLRequest) {
        if method == "GET" {
            sesh.timeoutIntervalForRequest = basic_timeout[0]
            sesh.timeoutIntervalForResource = basic_timeout[1]
        }
        if method == "POST" {
            sesh.timeoutIntervalForRequest = post_timeout[0]
            sesh.timeoutIntervalForResource = post_timeout[1]
        }

        var finished = false

        httpRequest(request: request, session: sesh) {
            finished = true
        }

        while !finished {
            RunLoop.current.run(mode: .default, before: .distantFuture)
        }
    }
}
