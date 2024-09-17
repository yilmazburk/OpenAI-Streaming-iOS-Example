//
//  NetworkManager.swift
//  StreamingServerSideEvents
//
//  Created by Burkan Yılmaz on 17.09.2024.
//

import Foundation

protocol EventDelegate: AnyObject {
    func onStream(result: Result<String?, NetworkError>)
}

final class NetworkManager: NSObject, URLSessionDataDelegate {
    
    weak var delegate: EventDelegate?
    
    private var apikey: String!
    private var session: URLSession?
    private var isStreamActive: Bool = false
    
    init(apikey: String, delegate: EventDelegate? = nil) {
        self.apikey = apikey
        self.delegate = delegate
    }
    
    func startStream(prompt: String) {
        guard let request = try? makeRequest(prompt: prompt) else {
            delegate?.onStream(result: .failure(.badEncoding))
            return
        }
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        sessionConfiguration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        
        session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        session?.dataTask(with: request).resume()
    }
    
    func startStream(prompt: String) async throws -> URLSession.AsyncBytes {
        let request = try makeRequest(prompt: prompt)
        return try await URLSession.shared.bytes(for: request).0
    }
    
    private func stopStream() {
        isStreamActive = false
        session?.invalidateAndCancel()
        session = nil
    }
    
    private func parse(_ line: String) -> String? {
        let components = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard components.count == 2, components[0] == "data" else { return nil }
        
        let message = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        if message == "[DONE]" {
            return "\n"
        } else {
            let chunk = try? JSONDecoder().decode(Chunk.self, from: message.data(using: .utf8)!)
            return chunk?.choices.first?.delta.content
        }
    }
    
    /// https://platform.openai.com/docs/api-reference/chat/create
    private func makeRequest(prompt: String) throws -> URLRequest {
        let eventRequest = ChatRequest(messages: [.init(role: "user", content: prompt)])
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(eventRequest)
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apikey!)"
        ]
        return request
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)
        
        isStreamActive = true
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard isStreamActive else { return }
        
        if let response = (dataTask.response as? HTTPURLResponse) {
            guard 200 ... 299 ~= response.statusCode else {
                stopStream()
                delegate?.onStream(result: .failure(.badRequest))
                return
            }
        }
        
        
        guard let dataString = String(data: data, encoding: .utf8) else { return }
        let lines = dataString.components(separatedBy: "\n")
        
        for line in lines where line.count > .zero {
            guard let message = parse(line) else { continue }
            delegate?.onStream(result: .success(message))
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil else {
            delegate?.onStream(result: .success(nil))
            return
        }
        stopStream()
        delegate?.onStream(result: .failure(.unknown))
    }
    
}

enum NetworkError: Error {
    case badRequest
    case unknown
    case badEncoding
}

struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    
    var model = "gpt-4o-mini"
    let messages: [Message]
    let stream = true
}

struct Chunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let role: String?
            let content: String?
        }
        
        let delta: Delta
    }
    
    let choices: [Choice]
}
