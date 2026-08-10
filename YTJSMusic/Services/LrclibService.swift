// YTJSMusic/Services/LrclibService.swift
import Foundation
import Combine

public class LrclibService: ObservableObject {
    public static let shared = LrclibService()
    
    private var cache = [String: LrclibResponse]()
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func fetchLyrics(for track: Track, completion: @escaping (Result<LrclibResponse, Error>) -> Void) {
        let cacheKey = track.recordingKey
        if let cached = cache[cacheKey] {
            completion(.success(cached))
            return
        }
        
        let trackName = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artistName = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let albumName = track.album.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationSec = Int(track.durationInSeconds)
        
        // 1. Primary Lookup via GET /api/get
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        if !albumName.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: albumName))
        }
        if durationSec > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(durationSec)))
        }
        components?.queryItems = queryItems
        
        guard let primaryUrl = components?.url else {
            completion(.failure(NSError(domain: "LrclibService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: primaryUrl)
        request.httpMethod = "GET"
        request.setValue("YTJSMusic/1.0 (https://github.com/YTJSMusic)", forHTTPHeaderField: "User-Agent")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, let data = data {
                if let decoded = try? JSONDecoder().decode(LrclibResponse.self, from: data) {
                    self?.cache[cacheKey] = decoded
                    completion(.success(decoded))
                    return
                }
            }
            
            // 2. Fallback to GET /api/search on 404 or any HTTP error
            self?.performSearchFallback(track: track, cacheKey: cacheKey, completion: completion)
        }
        task.resume()
    }
    
    private func performSearchFallback(track: Track, cacheKey: String, completion: @escaping (Result<LrclibResponse, Error>) -> Void) {
        let trackName = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artistName = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        
        guard let searchUrl = components?.url else {
            completion(.failure(NSError(domain: "LrclibService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No lyrics found"])))
            return
        }
        
        var request = URLRequest(url: searchUrl)
        request.httpMethod = "GET"
        request.setValue("YTJSMusic/1.0 (https://github.com/YTJSMusic)", forHTTPHeaderField: "User-Agent")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                  let candidates = try? JSONDecoder().decode([LrclibResponse].self, from: data),
                  !candidates.isEmpty else {
                completion(.failure(NSError(domain: "LrclibService", code: -404, userInfo: [NSLocalizedDescriptionKey: "No lyrics found on LRCLIB"])))
                return
            }
            
            let trackDur = track.durationInSeconds
            var bestCandidate: LrclibResponse? = nil
            var highestScore: Double = -999999.0
            
            for c in candidates {
                var score: Double = 0.0
                let candidateDur = c.duration ?? 0.0
                
                if trackDur > 0 && candidateDur > 0 {
                    let delta = abs(candidateDur - trackDur)
                    if delta > 15.0 { continue } // Exclude if outside 15-second tolerance
                    score -= (delta * 2.0)
                }
                
                if let synced = c.syncedLyrics, !synced.isEmpty {
                    score += 50.0
                }
                if let cArtist = c.artistName, cArtist.lowercased().contains(artistName.lowercased()) {
                    score += 30.0
                }
                
                if score > highestScore {
                    highestScore = score
                    bestCandidate = c
                }
            }
            
            if let winner = bestCandidate {
                self?.cache[cacheKey] = winner
                completion(.success(winner))
            } else if let fallbackFirst = candidates.first {
                self?.cache[cacheKey] = fallbackFirst
                completion(.success(fallbackFirst))
            } else {
                completion(.failure(NSError(domain: "LrclibService", code: -404, userInfo: [NSLocalizedDescriptionKey: "No suitable lyrics candidate found"])))
            }
        }
        task.resume()
    }
}
