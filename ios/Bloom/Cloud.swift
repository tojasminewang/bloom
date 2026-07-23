// Cloud.swift — cloud.js ported: email-code sign-in against Supabase auth, whole-garden
// sync to the `gardens` table, newest-edit-wins, substance-guarded first sync.
// Same project, same endpoints, same rules — one garden across web and iPhone.
import Foundation
import Observation

enum Cloud {
    static let url = "https://rbljgkthmbfvqtataocc.supabase.co"
    static let key = "sb_publishable__JUTOmE75UnmBQav7J9CCw_UbGu4iY8"
    static var configured: Bool { !url.isEmpty && !key.isEmpty }
}

struct CloudSession: Codable {
    var access_token: String
    var refresh_token: String?
    var userId: String
    var email: String?
}

enum SyncStatus: String {
    case idle, syncing, synced, error
}

@Observable
final class CloudSync {
    static let shared = CloudSync()

    private(set) var session: CloudSession?
    private(set) var status: SyncStatus = .idle
    @ObservationIgnored weak var store: AppStore?
    @ObservationIgnored private var pushWork: DispatchWorkItem?

    private static let account = "supabase-session"

    var signedIn: Bool { session?.access_token != nil }
    var userEmail: String? { session?.email }

    init() {
        if let data = Keychain.load(account: Self.account) {
            session = try? JSONDecoder().decode(CloudSession.self, from: data)
        }
    }

    private func saveSession(_ s: CloudSession?) {
        session = s
        if let s, let data = try? JSONEncoder().encode(s) {
            Keychain.save(data, account: Self.account)
        } else {
            Keychain.delete(account: Self.account)
        }
    }

    // MARK: - Boot

    /// Call once at launch: hook saves, refresh the session, reconcile gardens.
    func start(store: AppStore) {
        self.store = store
        store.onSave = { [weak self] in self?.queuePush() }
        guard Cloud.configured, signedIn else { return }
        Task {
            _ = await refreshSession()
            await firstSync()
        }
    }

    // MARK: - Requests

    private func headers(authed: Bool) -> [String: String] {
        var h = ["Content-Type": "application/json", "apikey": Cloud.key]
        // publishable keys aren't JWTs — only send Authorization once we hold a user token
        if authed, let token = session?.access_token { h["Authorization"] = "Bearer \(token)" }
        return h
    }

    private func request(_ path: String, method: String = "GET", authed: Bool, body: Data? = nil, extraHeaders: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: URL(string: Cloud.url + path)!)
        req.httpMethod = method
        for (k, v) in headers(authed: authed).merging(extraHeaders, uniquingKeysWith: { _, b in b }) {
            req.setValue(v, forHTTPHeaderField: k)
        }
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        return (data, resp as! HTTPURLResponse)
    }

    /// 401 → refresh → retry once, like the web's authedFetch.
    private func authedRequest(_ path: String, method: String = "GET", body: Data? = nil, extraHeaders: [String: String] = [:], retry: Bool = true) async throws -> (Data, HTTPURLResponse) {
        let (data, resp) = try await request(path, method: method, authed: true, body: body, extraHeaders: extraHeaders)
        if resp.statusCode == 401, retry, await refreshSession() {
            return try await authedRequest(path, method: method, body: body, extraHeaders: extraHeaders, retry: false)
        }
        return (data, resp)
    }

    // MARK: - Auth

    struct AuthError: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    private static func serverMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (obj["msg"] ?? obj["error_description"] ?? obj["message"]) as? String
    }

    /// Sends the sign-in email (magic link + code, once the template includes {{ .Token }}).
    func requestCode(email: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "create_user": true])
        let (data, resp) = try await request("/auth/v1/otp", method: "POST", authed: false, body: body)
        guard (200..<300).contains(resp.statusCode) else {
            throw AuthError(message: Self.serverMessage(data) ?? "Could not send the code")
        }
    }

    /// Types the 6-digit code from the email → session → first sync.
    func verifyCode(email: String, code: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "token": code, "type": "email"])
        let (data, resp) = try await request("/auth/v1/verify", method: "POST", authed: false, body: body)
        guard (200..<300).contains(resp.statusCode),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String
        else {
            throw AuthError(message: Self.serverMessage(data) ?? "Wrong or expired code")
        }
        let refresh = obj["refresh_token"] as? String
        let user = obj["user"] as? [String: Any]
        saveSession(CloudSession(
            access_token: access,
            refresh_token: refresh,
            userId: user?["id"] as? String ?? "",
            email: user?["email"] as? String ?? email
        ))
        await firstSync()
    }

    @discardableResult
    private func refreshSession() async -> Bool {
        guard let refresh = session?.refresh_token else { return false }
        do {
            let body = try JSONSerialization.data(withJSONObject: ["refresh_token": refresh])
            let (data, resp) = try await request("/auth/v1/token?grant_type=refresh_token", method: "POST", authed: false, body: body)
            if (200..<300).contains(resp.statusCode),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let access = obj["access_token"] as? String {
                let user = obj["user"] as? [String: Any]
                saveSession(CloudSession(
                    access_token: access,
                    refresh_token: obj["refresh_token"] as? String ?? refresh,
                    userId: user?["id"] as? String ?? session?.userId ?? "",
                    email: user?["email"] as? String ?? session?.email
                ))
                return true
            }
            // sign out only when the token is definitively dead — hiccups keep you signed in
            if [400, 401, 403].contains(resp.statusCode) {
                saveSession(nil)
                await MainActor.run { status = .idle }
            }
            return false
        } catch {
            return false   // offline — stay signed in, try again next time
        }
    }

    func signOut() {
        Task { _ = try? await authedRequest("/auth/v1/logout", method: "POST") }
        saveSession(nil)
        status = .idle
        store?.toast("Signed out — this phone keeps its local copy", "leaf")
    }

    // MARK: - Garden sync (one row per user, whole garden as JSON, newest edit wins)

    private struct PushBody: Encodable {
        var user_id: String
        var data: BloomState
        var edited_at: String
    }

    private struct PullRow: Decodable {
        var data: BloomState
        var edited_at: String?
    }

    func queuePush() {
        guard signedIn else { return }
        pushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { await self?.pushGarden() }
        }
        pushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func pushGarden() async {
        guard signedIn, let store else { return }
        await MainActor.run { status = .syncing }
        do {
            let payload = await MainActor.run {
                PushBody(user_id: session?.userId ?? "", data: store.state,
                         edited_at: store.state.editedAt ?? nowISO())
            }
            let body = try JSONEncoder().encode(payload)
            let (_, resp) = try await authedRequest("/rest/v1/gardens", method: "POST", body: body,
                                                    extraHeaders: ["Prefer": "resolution=merge-duplicates"])
            await MainActor.run { status = (200..<300).contains(resp.statusCode) ? .synced : .error }
        } catch {
            await MainActor.run { status = .error }
        }
    }

    private func pullGarden() async -> PullRow? {
        guard let uid = session?.userId else { return nil }
        guard let (data, resp) = try? await authedRequest("/rest/v1/gardens?select=data,edited_at&user_id=eq.\(uid)"),
              (200..<300).contains(resp.statusCode),
              let rows = try? JSONDecoder().decode([PullRow].self, from: data)
        else { return nil }
        return rows.first
    }

    /// After sign-in (or at boot): a garden with actual plants beats an empty one,
    /// no matter the timestamps; only between two real gardens does newest-edit win.
    func firstSync() async {
        guard let store else { return }
        await MainActor.run { status = .syncing }
        let row = await pullGarden()
        await MainActor.run {
            let cloudHas = row?.data.substance ?? 0
            let localHas = store.state.substance
            let cloudNewer = row != nil && (row?.edited_at ?? "") > (store.state.editedAt ?? "")
            if let row, cloudHas > 0, localHas == 0 || cloudNewer {
                store.replace(row.data)
                store.toast("Your garden is back", "flower")
                status = .synced
            } else if localHas == 0 && cloudNewer {
                status = .synced   // both empty, cloud current — nothing worth writing either way
            } else {
                Task { await self.pushGarden() }
            }
        }
    }
}
