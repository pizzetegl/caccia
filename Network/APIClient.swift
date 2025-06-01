//
//  APIClient.swift
//  ARGeoApp
//
//  Created by Lorenzo Conti on 22/04/25.
//

import Foundation

class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://tavernadeldrago.it/arprova"

    func fetchModels(completion: @escaping ([ARModel]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api.php/models") else {
            print("❌ URL non valido: \(baseURL)/api.php/models")
            completion([])
            return
        }
        print("📡 Chiamata API: \(url)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Errore di rete: \(error.localizedDescription)")
            }
            if let http = response as? HTTPURLResponse {
                print("⏱ Status code: \(http.statusCode)")
            }
            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("📥 Response body:\n\(body)")
            }
            guard let data = data else {
                completion([])
                return
            }
            do {
                let models = try JSONDecoder().decode([ARModel].self, from: data)
                DispatchQueue.main.async {
                    completion(models)
                }
            } catch {
                print("❌ Decoding error: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
    }
    
    /// Fetch models filtered by a specific prova
    func fetchModels(prova: Int, completion: @escaping ([ARModel]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api.php/models?prova=\(prova)") else {
            print("❌ URL non valido: \(baseURL)/api.php/models?prova=\(prova)")
            completion([])
            return
        }
        print("📡 Chiamata API (prova \(prova)): \(url)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Errore di rete: \(error.localizedDescription)")
            }
            if let http = response as? HTTPURLResponse {
                print("⏱ Status code: \(http.statusCode)")
            }
            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("📥 Response body:\n\(body)")
            }
            guard let data = data else {
                completion([])
                return
            }
            do {
                let models = try JSONDecoder().decode([ARModel].self, from: data)
                DispatchQueue.main.async {
                    completion(models)
                }
            } catch {
                print("❌ Decoding error: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
    }
    
    /// Authenticate a user against the MySQL users table
    func login(username: String,
               password: String,
               completion: @escaping (Bool, Int?, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/login_ar.php") else {
            completion(false, nil, "URL non valido")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username, "password": password]
        request.httpBody = try? JSONEncoder().encode(body)
        
        print("🔑 Login API URL: \(url)")
        if let httpBody = request.httpBody, let bodyString = String(data: httpBody, encoding: .utf8) {
            print("🔑 Login request body: \(bodyString)")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Capture and log HTTP status code
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            print("🔑 Login status code: \(statusCode ?? -1)")
            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("🔑 Login response body: \(body)")
            }
            if let error = error {
                print("🔑 Login network error: \(error.localizedDescription)")
            }

            if let error = error {
                DispatchQueue.main.async {
                    completion(false, statusCode, "Network error: \(error.localizedDescription) (status: \(statusCode ?? -1))")
                }
                return
            }

            // Check for non-200 responses
            if let code = statusCode, code != 200 {
                DispatchQueue.main.async {
                    completion(false, code, "Server error: \(code)")
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(false, statusCode, "No response from server (status: \(statusCode ?? -1))")
                }
                return
            }
            struct LoginResponse: Decodable {
                let success: Bool
                let error: String?
                let provaAttuale: Int?
                enum CodingKeys: String, CodingKey {
                    case success, error
                    case provaAttuale = "prova_attuale"
                }
            }
            do {
                let resp = try JSONDecoder().decode(LoginResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(resp.success, resp.provaAttuale, resp.error)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, statusCode, "Risposta non valida")
                }
            }
        }.resume()
    }
    
    /// Poll the server for the current prova (without re-login)
    func fetchCurrentProva(username: String, completion: @escaping (Bool, Int?, String?) -> Void) {
        // We rely on login_ar.php supporting GET?username=... to return prova_attuale
        var components = URLComponents(string: "\(baseURL)/login_ar.php")
        components?.queryItems = [URLQueryItem(name: "username", value: username)]
        guard let url = components?.url else {
            completion(false, nil, "URL non valido per fetchCurrentProva")
            return
        }
        print("📡 Fetch prova: \(url)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            print("⏱ Prova status code: \(statusCode ?? -1)")
            if let error = error {
                print("❌ Prova network error: \(error)")
                DispatchQueue.main.async {
                    completion(false, statusCode, error.localizedDescription)
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(false, statusCode, "Nessun dato per fetchCurrentProva")
                }
                return
            }
            struct ProvaResponse: Decodable {
                let success: Bool
                let provaAttuale: Int?
                let error: String?
                enum CodingKeys: String, CodingKey {
                    case success, error
                    case provaAttuale = "prova_attuale"
                }
            }
            do {
                let resp = try JSONDecoder().decode(ProvaResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(resp.success, resp.provaAttuale, resp.error)
                }
            } catch {
                print("❌ Prova decoding error: \(error)")
                DispatchQueue.main.async {
                    completion(false, statusCode, "Decoding fetchCurrentProva fallito")
                }
            }
        }.resume()
    }
}
