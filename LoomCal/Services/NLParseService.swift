import ConvexMobile
import Foundation

/// NLParseService manages the Convex parse request lifecycle:
/// 1. Creates a parse request via mutation (client-generated requestId)
/// 2. Subscribes to the result via query (reactive updates)
/// 3. Returns the parsed result when complete, or nil on error/timeout
///
/// Used by EventCreationView and TaskCreationView for Loom-powered NL parsing.
/// Falls back gracefully — callers handle nil by using local parsing or raw input.
@MainActor
final class NLParseService {
    static let shared = NLParseService()
    private init() {}

    /// Submit an NL parse request to Convex and wait for the bridge to process it.
    /// Returns the completed result, or nil on error/timeout (10 seconds).
    func parse(text: String, type: String) async -> ParsedNLResult? {
        let requestId = UUID().uuidString

        // 1. Create parse request in Convex
        let createArgs: [String: ConvexEncodable?] = [
            "requestId": requestId,
            "text": text,
            "type": type,
        ]
        do {
            try await convex.mutation("nlParse:createParseRequest", with: createArgs)
        } catch {
            return nil
        }

        // 2. Subscribe and wait for result with timeout
        let subscribeArgs: [String: ConvexEncodable?] = ["requestId": requestId]

        return await withTaskGroup(of: ParsedNLResult?.self) { group in
            // Race: subscription vs timeout
            group.addTask {
                for await result: ParsedNLResult? in convex
                    .subscribe(to: "nlParse:getResult", with: subscribeArgs)
                    .replaceError(with: Optional<ParsedNLResult>.none)
                    .values
                {
                    guard let result else { continue }
                    if result.status == "complete" || result.status == "error" {
                        return result
                    }
                    // Still "pending" — wait for next subscription update
                }
                return nil
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                return nil
            }

            // First to finish wins
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
