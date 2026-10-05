//
//  MarketplaceCoreTests.swift
//  RepairMarketplaceTests
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

@main
struct MarketplaceCoreTests {
    static func main() throws {
        let defaults = TestCacheStorage()
        let client = TestMarketplaceAPI()
        let store = MarketplaceStore(client: client, defaults: defaults)
        let remote = RepairOrder(id: "real-1", customerId: MarketplaceRole.customer.actorID, workerId: "", category: "家电维修", equipment: "test", issue: "test", address: "test", scheduledAt: "", status: .pendingWorker, paymentStatus: "not_started", quotedAmountCents: 0, platformFeeCents: 0, workerShareCents: 0, createdAt: "", updatedAt: "")
        for (text, expected) in [("128.50", Int64(12850)), ("0.01", 1), ("1000000", 100000000), (".50", 50), ("1,25", 125)] {
            expect(MarketplaceMoney.quoteCents(from: text) == expected, "valid decimal " + text)
        }
        for text in ["0", "0.001", "1000000.01", "999999999999999999999999999999999999", "inf", "nan", "1e100", "-1", "1,000.50"] {
            expect(MarketplaceMoney.quoteCents(from: text) == nil, "reject invalid / overflow " + text)
        }
        client.response = try JSONEncoder.make { _ in }.encode([remote])
        store.listOrders(for: .customer) { outcome in
            expect(outcome.source == .server && outcome.value.count == 1, "server snapshot contains only real order")
        }
        expect(client.requestedPaths.last == "/api/v1/orders?limit=200", "explicit maximum list window")
        client.response = Data("[]".utf8)
        store.listOrders(for: .customer) { outcome in
            expect(outcome.value.isEmpty, "empty server list replaces old snapshot")
        }
        expect(store.previewOrders(for: .customer).value.isEmpty, "empty snapshot persists")
        client.failure = MarketplaceRemoteFailure(kind: .rejected, statusCode: 409, detail: "already taken")
        store.listOrders(for: .customer) { outcome in
            expect(outcome.source == .demo && outcome.value.allSatisfy { $0.id.hasPrefix("demo-") }, "offline has no stale real order")
        }
        store.transition(order: remote, action: "accept", role: .worker) { outcome in
            expect(outcome.value?.status == .accepted && outcome.value?.demoSourceID == remote.id, "409 still permits independent demo copy")
            expect(outcome.value?.id != remote.id && outcome.failure?.statusCode == 409, "demo uses distinct identity and retains rejection")
        }
        expect(store.previewOrders(for: .customer).value.isEmpty, "demo transition cannot overwrite empty real snapshot")
        store.transition(order: remote, action: "accept", role: .worker) { outcome in
            expect(outcome.value == nil, "stale pending snapshot cannot repeat accept over latest demo")
        }
        store.transition(order: remote, action: "arrive", role: .worker) { outcome in
            expect(outcome.value?.status == .arrived, "demo uses latest accepted state for arrival")
        }
        store.transition(order: remote, action: "quote", role: .worker, quoteCents: MarketplaceMoney.maximumQuoteCents + 1) { outcome in
            expect(outcome.value == nil, "local state machine enforces the shared quote upper bound")
        }
        store.transition(order: remote, action: "quote", role: .worker, quoteCents: MarketplaceMoney.maximumQuoteCents) { outcome in
            expect(outcome.value?.status == .quotePending, "maximum valid quote enters approval")
        }
        store.transition(order: remote, action: "confirm-quote", role: .customer) { outcome in
            expect(outcome.value?.status == .inService, "customer sees worker demo quote and approves")
        }
        store.transition(order: remote, action: "complete", role: .worker) { outcome in
            expect(outcome.value?.status == .awaitingPayment, "worker sees customer approval and completes")
        }
        expect(store.previewOrders(for: .customer).value.isEmpty, "demo workflow does not modify empty server snapshot")
        client.failure = nil
        client.response = Data("[]".utf8)
        store.listCategories { outcome in
            expect(outcome.source == .server && outcome.value.isEmpty, "empty remote categories remain empty")
        }
        client.failure = MarketplaceRemoteFailure(kind: .rejected, statusCode: 409, detail: "already taken")
        store.listCategories { outcome in
            expect(outcome.source == .demo && outcome.value == RepairCategory.all, "failed categories retain local services")
        }
        let input = CreateRepairOrder(category: "家电维修", equipment: "test", issue: "test", address: "test", scheduledAt: "")
        var submission = MarketplaceOrderSubmission()
        let attemptKey = submission.key(for: input)
        expect(submission.key(for: input) == attemptKey, "same form content reuses actual attempt key")
        var edited = input
        edited.issue = "edited"
        expect(submission.key(for: edited) != attemptKey, "edited form receives a new key")
        var separateForm = MarketplaceOrderSubmission()
        expect(separateForm.key(for: input) != attemptKey, "separate form does not reuse key")
        for _ in 0..<2 {
            store.createOrder(input, idempotencyKey: "form-key") { outcome in
                expect(outcome.value?.id == "demo-create-form-key", "same request key reuses demo order")
            }
        }
        expect(client.idempotencyKeys.filter { $0 == "form-key" }.count == 2, "same Idempotency-Key sent on manual retry")
        store.listOrders(for: .worker) { outcome in
            expect(outcome.value.filter { $0.id == "demo-create-form-key" }.count == 1, "customer-created demo visible once to worker")
        }
        let before = store.previewOrders(for: .customer).value
        MarketplaceEnvironment.baseURLString = "http://other.example:8080"
        expect(store.previewOrders(for: .customer).source == .demo, "new environment has independent snapshot")
        expect(store.previewOrders(for: .customer).value.allSatisfy { $0.id != "demo-create-form-key" }, "new environment does not share demo records")
        MarketplaceEnvironment.baseURLString = "http://test.example:8080"
        expect(store.previewOrders(for: .customer).value.count == before.count, "original empty snapshot survives environment switch")
        client.failure = MarketplaceRemoteFailure(kind: .unknown, statusCode: nil, detail: "response lost")
        store.createOrder(input, idempotencyKey: "unknown-key") { outcome in
            expect(outcome.source == .demo && outcome.failure?.kind == .unknown, "lost write response stays unknown")
        }
        expect(store.previewOrders(for: .customer).value.isEmpty, "unknown write does not overwrite real snapshot")
        client.failure = nil
        client.response = try JSONEncoder.make { _ in }.encode([remote])
        store.listOrders(for: .customer) { outcome in
            expect(outcome.source == .server && outcome.value.map(\.id) == ["real-1"], "service recovery automatically uses true data")
        }
        let cache = MarketplaceOrderCache(defaults: defaults)
        let customerScope = MarketplaceOrderCache.Scope(environment: "test", baseURL: MarketplaceEnvironment.baseURLString, role: .customer, actorID: MarketplaceRole.customer.actorID)
        let workerScope = MarketplaceOrderCache.Scope(environment: "test", baseURL: MarketplaceEnvironment.baseURLString, role: .worker, actorID: MarketplaceRole.customer.actorID)
        let otherActorScope = MarketplaceOrderCache.Scope(environment: "test", baseURL: MarketplaceEnvironment.baseURLString, role: .customer, actorID: "other-actor")
        expect(cache.snapshot(for: customerScope)?.count == 1, "customer snapshot present")
        expect(cache.snapshot(for: workerScope) == nil, "same actor with different role does not share snapshot")
        expect(cache.snapshot(for: otherActorScope) == nil, "different actor does not share snapshot")
        let legacyDefaults = TestCacheStorage()
        let legacyCache = MarketplaceOrderCache(defaults: legacyDefaults)
        var legacyDemo = remote
        legacyDemo.id = "demo-legacy"
        legacyDefaults.set(try JSONEncoder.make { _ in }.encode([remote, legacyDemo]), forKey: "repair.demo.orders.test." + MarketplaceEnvironment.baseURLString)
        expect(legacyCache.demoOrders(for: customerScope).map(\.id) == ["demo-legacy"], "legacy migration excludes real records")
        let context = MarketplaceRequestContext(pageRevision: 1, role: .customer, environmentRevision: 0)
        expect(context != MarketplaceRequestContext(pageRevision: 2, role: .customer, environmentRevision: 0), "late page callback rejected by revision")
        expect(context != MarketplaceRequestContext(pageRevision: 1, role: .worker, environmentRevision: 0), "late role callback rejected")
        var dated = input
        expect(dated.validationMessageKey == nil, "blank appointment allowed")
        dated.scheduledAt = "今天14:00"
        expect(dated.validationMessageKey != nil, "relative demo appointment rejected")
        dated.scheduledAt = "2026-10-05T14:00:00+08:00"
        expect(dated.validationMessageKey == nil, "RFC3339 with timezone accepted")
        dated.scheduledAt = "2026-10-05T14:00:00.123Z"
        expect(dated.validationMessageKey == nil, "RFC3339 fractional seconds accepted")
        dated.scheduledAt = "2026-10-05T14:00:00"
        expect(dated.validationMessageKey != nil, "appointment without timezone rejected")
        for time in ["2026-02-30T14:00:00+08:00", "2026-10-05T25:00:00Z", "2026-10-05T14:00:00+08:60", "2026-10-05T14:00:60Z"] {
            dated.scheduledAt = time
            expect(dated.validationMessageKey != nil, "invalid calendar / time rejected: " + time)
        }
        dated.scheduledAt = "2028-02-29T14:00:00+08:00"
        expect(dated.validationMessageKey == nil, "valid leap day accepted")
        dated.scheduledAt = ""
        dated.equipment = String(repeating: "a\u{0301}", count: 81)
        expect(dated.validationMessageKey != nil, "length matches Go rune count for combining characters")
        try accountAndPrivateDataTests()
        print("PASS: decimal bounds, empty snapshot, demo separation, HTTP rejection / unknown writes, stale transitions, form idempotency, environment / role / actor isolation, legacy migration, server recovery, page revision, appointment validation")
    }

    private static func accountAndPrivateDataTests() throws {
        let credentials = MarketplaceKeychain()
        let sessions = MarketplaceSessionCenter(credentials: credentials)
        sessions.configureIdentityProvider()
        defer {
            MarketplaceIdentityContext.actorIDProvider = nil
            MarketplaceEnvironment.baseURLString = "http://test.example:8080"
        }
        let client = TestMarketplaceAPI()
        let accounts = MarketplaceAccountStore(client: client, sessions: sessions)
        let input = MarketplaceAuthInput(username: "worker_1", password: "password-12345", displayName: "Test worker", role: .worker)
        expect(input.validationMessage(registering: true) == nil, "valid registration input")
        var invalid = input
        invalid.username = "worker name"
        expect(invalid.validationMessage(registering: true) != nil, "username rejects spaces")
        invalid = input
        invalid.password = "short"
        expect(invalid.validationMessage(registering: true) != nil, "registration enforces password length")
        client.failure = MarketplaceRemoteFailure(kind: .rejected, statusCode: 401, detail: "bad credentials")
        accounts.authenticate(input, registering: false) { result in
            guard case .failure = result else {
                fatalError("Failed authentication created a session")
            }
        }
        expect(sessions.current == nil && credentials.values.isEmpty, "failed login cannot invent or persist a session")
        let device = MarketplaceDeviceSession(id: "session-mobile", device: MarketplaceDevice(kind: "mobile", label: "Test phone", platform: "iOS"), authMethod: "password", capabilities: ["manage_devices", "authorize_qr"], createdAt: "2026-10-05T00:00:00Z", expiresAt: "2099-10-05T00:00:00Z", isCurrent: true)
        let user = MarketplaceUser(id: "worker-real-1", username: "worker_1", displayName: "Test worker", role: "worker")
        let first = MarketplaceSession(token: "test-token-1", expiresAt: device.expiresAt, user: user, session: device)
        client.failure = nil
        client.response = try JSONEncoder.make { _ in }.encode(first)
        var wrongRole = input
        wrongRole.role = .customer
        accounts.authenticate(wrongRole, registering: false) { result in
            guard case .failure = result else {
                fatalError("A worker session entered the customer business")
            }
        }
        expect(sessions.current == nil, "server identity must match the selected entry role")
        credentials.canSave = false
        accounts.authenticate(input, registering: true) { result in
            guard case .failure = result else {
                fatalError("Unsafe credential storage was accepted")
            }
        }
        expect(sessions.current == nil, "failed secure storage does not publish a logged-in state")
        credentials.canSave = true
        accounts.authenticate(input, registering: true) { result in
            guard case .success(let current) = result else {
                fatalError("Valid sign-in failed")
            }
            expect(current.id == user.id, "server user determines actor identity")
        }
        expect(sessions.current?.session?.capabilities == device.capabilities, "mobile management capabilities decoded")
        expect(MarketplaceRole.worker.actorID == user.id && MarketplaceRole.customer.actorID == MarketplaceRole.customer.demoActorID, "real actor is injected only for its server role")
        let requestDevice = client.requestedBodies.last??["device"]?.raw as? [String: String]
        expect(requestDevice?["kind"] == "mobile", "iOS authentication declares a mobile device")
        let firstScope = sessions.scope
        MarketplaceEnvironment.baseURLString = "http://other.example:8080"
        expect(sessions.current == nil, "credentials are isolated by endpoint")
        MarketplaceEnvironment.baseURLString = "http://test.example:8080"
        expect(sessions.current?.token == first.token, "original Keychain scope can be restored")
        sessions.enterLocalDemo(role: .customer)
        expect(sessions.current?.user.role == "worker", "demo role cannot override an authenticated server role")

        let defaults = TestCacheStorage()
        let privateCache = MarketplacePrivateCache(defaults: defaults)
        privateCache.write("server-value", key: "identity-check", role: .worker, demo: false)
        privateCache.write("demo-value", key: "identity-check", role: .worker, demo: true)
        expect(privateCache.read(String.self, key: "identity-check", role: .worker, demo: false) == "server-value", "private demo cannot overwrite snapshot")
        let secondUser = MarketplaceUser(id: "worker-real-2", username: "worker_2", displayName: "Other worker", role: "worker")
        let second = MarketplaceSession(token: "test-token-2", expiresAt: device.expiresAt, user: secondUser, session: device)
        expect(sessions.save(second, notice: "test"), "second test account can be saved")
        expect(privateCache.read(String.self, key: "identity-check", role: .worker, demo: false) == nil, "private cache does not cross accounts")
        expect(sessions.save(first, notice: "test"), "original test account can be restored")
        expect(defaults.values.values.allSatisfy { String(decoding: $0, as: UTF8.self).contains(first.token) == false }, "preference caches do not contain tokens")
        let orderCache = MarketplaceOrderCache(defaults: defaults)
        let realScope = MarketplaceOrderCache.Scope(environment: "test", baseURL: MarketplaceEnvironment.baseURLString, role: .worker, actorID: user.id)
        let demoScope = MarketplaceOrderCache.Scope(environment: "test", baseURL: MarketplaceEnvironment.baseURLString, role: .worker, actorID: MarketplaceRole.worker.demoActorID)
        var accountDemo = RepairOrder(id: "demo-account-private", customerId: "customer-real", workerId: user.id, category: "家电维修", equipment: "test", issue: "test", address: "test", scheduledAt: "", status: .pendingWorker, paymentStatus: "not_started", quotedAmountCents: 0, platformFeeCents: 0, workerShareCents: 0, createdAt: "", updatedAt: "")
        orderCache.saveDemo(accountDemo, in: realScope)
        expect(orderCache.demoOrders(for: realScope).contains { $0.id == accountDemo.id }, "real account keeps its local demo")
        expect(orderCache.demoOrders(for: demoScope).contains { $0.id == accountDemo.id } == false, "real account demo never enters anonymous demo audience")
        accountDemo.id = "demo-legacy-private"
        defaults.set(try JSONEncoder.make { _ in }.encode([accountDemo]), forKey: "repair.demo.orders.test." + MarketplaceEnvironment.baseURLString)
        let anotherScope = MarketplaceOrderCache.Scope(environment: "test", baseURL: MarketplaceEnvironment.baseURLString, role: .worker, actorID: secondUser.id)
        expect(orderCache.demoOrders(for: anotherScope).contains { $0.id == accountDemo.id } == false, "legacy demo migration cannot leak into authenticated account")

        let workers = MarketplaceWorkerStore(client: client, assets: client, defaults: defaults)
        var approved = MarketplaceWorkerApplication.localDraft(actorID: user.id)
        approved.id = "application-real-1"
        approved.status = "approved"
        approved.revision = 7
        approved.displayName = "Test worker"
        approved.contactPhone = "Contact example"
        approved.serviceAreas = ["Example area"]
        approved.skills = ["Example skill"]
        approved.assetIds = ["asset-owned"]
        var pendingJSON = try JSONSerialization.jsonObject(with: JSONEncoder.make { _ in }.encode(approved)) as! [String: Any]
        pendingJSON["reviewedAt"] = NSNull()
        let pendingApplication = try JSONDecoder.make { _ in }.decode(MarketplaceWorkerApplication.self, from: JSONSerialization.data(withJSONObject: pendingJSON))
        expect(pendingApplication.reviewedAt == nil, "unreviewed application accepts server null reviewedAt")
        client.response = try JSONEncoder.make { _ in }.encode(approved)
        workers.fetch { outcome in
            expect(outcome.source == .server && outcome.value?.status == "approved", "worker review status is server-derived")
        }
        let draft = MarketplaceWorkerDraft(application: approved)
        expect(draft.validationMessage == nil && draft.expectedRevision == 7, "editing preserves review revision")
        client.failure = MarketplaceRemoteFailure(kind: .rejected, statusCode: 409, detail: "revision conflict")
        workers.submit(draft) { outcome in
            expect(outcome.source == .demo && outcome.value?.status == "pending" && outcome.failure?.statusCode == 409, "rejected application can only create unconfirmed pending demo")
        }
        expect(workers.preview().value?.status == "approved", "local application submission cannot replace real review snapshot")
        let submitBody = client.requestedBodies.last ?? nil
        expect(submitBody?["expectedRevision"]?.raw as? Int == 7 && submitBody?["status"] == nil && submitBody?["reviewNote"] == nil, "client never submits review authority fields")
        workers.upload(Data([1, 2, 3])) { outcome in
            expect(outcome.source == .demo && outcome.value?.id.hasPrefix("demo-asset-") == true, "failed private upload gets an explicit demo asset ID")
        }
        let beforeImage = client.requestedPaths.count
        workers.image(assetID: "demo-asset-local") { result in
            guard case .failure = result else {
                fatalError("Demo asset was treated as a private server image")
            }
        }
        expect(client.requestedPaths.count == beforeImage, "demo asset does not call a private image route")
        client.failure = MarketplaceRemoteFailure(kind: .rejected, statusCode: 404, detail: "wrong route")
        workers.fetch { outcome in
            expect(outcome.source == .demo, "unstructured route 404 cannot pretend to confirm no application")
        }
        expect(workers.preview().value?.status == "approved", "route 404 keeps previous confirmed application snapshot")
        client.failure = MarketplaceRemoteFailure(kind: .rejected, statusCode: 404, detail: "not found", code: "not_found")
        workers.fetch { outcome in
            expect(outcome.source == .server && outcome.value == nil, "no application is a normal server empty state")
        }
        expect(workers.preview().source == .snapshot && workers.preview().value == nil, "404 clears previous application snapshot")

        let ledger = MarketplaceLedgerStore(client: client, defaults: defaults)
        client.failure = nil
        let journal = MarketplaceLedgerJournal(id: "journal-1", eventKey: "collection:test", orderId: "order-real-1", customerId: "customer-real", workerId: user.id, settlementId: "", mode: "simulated", simulated: true, kind: "collection", channel: "demo", status: "posted", amountCents: 125, workerShareCents: 100, platformFeeCents: 25, occurredAt: "2026-10-05T00:00:00Z", actorId: "admin-test", reason: "test", reversalOfId: "", entries: [])
        client.response = try JSONEncoder.make { _ in }.encode([journal])
        ledger.journals(role: .worker) { outcome in
            expect(outcome.source == .server && outcome.value.count == 1, "private simulated journal decoded")
        }
        client.response = Data("[]".utf8)
        ledger.journals(role: .worker) { outcome in
            expect(outcome.source == .server && outcome.value.isEmpty, "ledger empty response replaces snapshot")
        }
        expect(ledger.previewJournals(role: .worker).value.isEmpty, "empty private journal snapshot persists")
        client.failure = MarketplaceRemoteFailure(kind: .unavailable, statusCode: nil, detail: "offline")
        ledger.summary(role: .worker) { outcome in
            expect(outcome.source == .demo && outcome.failure != nil, "ledger fallback is visibly unconfirmed, not a real zero balance")
        }
        expect(MarketplaceMoney.amountText(cents: Int64.min) == "-¥92233720368547758.08", "ledger currency formatter handles full signed integer range")

        let devices = MarketplaceDeviceStore(client: client, defaults: defaults)
        client.failure = nil
        client.response = try JSONEncoder.make { _ in }.encode([device])
        devices.fetch(role: .worker) { outcome in
            expect(outcome.source == .server && outcome.value.first?.isCurrent == true, "current device flag decoded")
        }
        client.failure = MarketplaceRemoteFailure(kind: .unknown, statusCode: nil, detail: "response lost")
        devices.revoke("session-other", role: .worker) { result in
            guard case .failure = result else {
                fatalError("Lost revocation response was reported as success")
            }
        }
        expect(client.requestedPaths.last == "/api/v1/auth/devices/session-other" && client.requestedMethods.last == .delete, "revocation targets only one device session")
        expect(devices.preview(role: .worker).value.count == 1, "failed revocation cannot claim all devices have logged out")

        let validURI = "repairmarketplace://login?challengeId=challenge-test&approvalCode=abcdefghijklmnop"
        guard let login = MarketplaceQRLogin(uri: validURI) else {
            fatalError("Valid platform QR URI failed")
        }
        for uri in ["https://example.com/?challengeId=x&approvalCode=abcdefghijklmnop", validURI + "&challengeId=other", validURI + "#fragment", "repairmarketplace://login?challengeId=../other&approvalCode=abcdefghijklmnop", "repairmarketplace://login?challengeId=x&approvalCode=short"] {
            expect(MarketplaceQRLogin(uri: uri) == nil, "QR rejects wrong origin, duplicate fields, path injection or incomplete secrets")
        }
        let qr = MarketplaceQRStore(client: client)
        client.failure = nil
        let challenge = MarketplaceQRChallenge(id: login.challengeID, device: MarketplaceDevice(kind: "desktop", label: "Test PC", platform: "Windows"), expiresAt: "2099-10-05T00:00:00Z", status: "pending")
        client.response = try JSONSerialization.data(withJSONObject: ["id": challenge.id, "device": ["kind": "desktop", "label": "Test PC", "platform": "Windows"], "expiresAt": challenge.expiresAt, "status": challenge.status])
        let beforeQR = client.requestedPaths.count
        qr.inspect(login, role: .worker) { result in
            guard case .success(let response) = result else {
                fatalError("QR inspection failed")
            }
            expect(response.mayConfirm, "fresh pending QR can be explicitly confirmed")
        }
        expect(client.requestedPaths.count == beforeQR + 1 && client.requestedPaths.last?.hasSuffix("/inspect") == true, "inspection never automatically approves a QR login")
        expect(client.requestedPaths.last?.contains(login.approvalCode) == false, "QR approval secret stays in body, not logged URL")
        client.response = Data("{\"status\":\"rejected\"}".utf8)
        qr.decide(login, approve: false, role: .worker) { result in
            guard case .success(let decision) = result else {
                fatalError("Explicit QR rejection failed")
            }
            expect(decision.status == "rejected", "QR rejection requires server result")
        }
        expect(client.requestedBodies.last??["decision"]?.raw as? String == "reject", "explicit rejection is sent to server")
        client.response = Data("{\"status\":\"pending\"}".utf8)
        qr.decide(login, approve: true, role: .worker) { result in
            guard case .failure(let failure) = result, failure.kind == .unknown else {
                fatalError("Unexpected QR decision status was reported as confirmation")
            }
        }

        client.response = Data("{}".utf8)
        client.deferResponses = true
        accounts.logout()
        expect(sessions.current == nil, "logout clears only the current local credential immediately")
        expect(sessions.save(second, notice: "test"), "new sign-in while old logout response is pending")
        client.flush()
        expect(sessions.current?.token == second.token, "late logout response cannot erase a newer login")
        expect(credentials.values[firstScope] != nil, "new credential is preserved after old logout")
        print("PASS: strict authentication, secure storage boundary, mobile capabilities, identity/cache isolation, private review and upload, ledger empty state, single-device revocation, strict QR inspection/decision, late logout protection")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError("FAIL: " + message)
        }
    }
}
