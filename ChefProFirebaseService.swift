import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ChefProFirebaseService: ObservableObject {
    static let shared = ChefProFirebaseService()

    private let db = Firestore.firestore()

    // ── Keys ─────────────────────────────────────────────────────────────
    private let restaurantIDKey = "chefpro_restaurant_id"
    private let deviceIDKey     = "chefpro_device_id"

    // ── Device ID (unique per install, never shared) ──────────────────────
    var deviceID: String {
        if let saved = UserDefaults.standard.string(forKey: deviceIDKey) { return saved }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIDKey)
        return id
    }

    // ── Restaurant ID (shared between devices for sync) ───────────────────
    var restaurantID: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: restaurantIDKey) { return saved }
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: restaurantIDKey)
            return newID
        }
    }

    /// Sync code — first 8 chars, uppercase, easy to type/share
    var syncCode: String {
        String(restaurantID.replacingOccurrences(of: "-", with: "").prefix(8).uppercased())
    }

    // ── Real-time listener ─────────────────────────────────────────────────
    private var changeListener: ListenerRegistration?

    /// Starts Firestore snapshot listener. Calls `onRemoteChange` only when
    /// the update originated on ANOTHER device (compares lastUpdatedByDevice).
    func startListening(onRemoteChange: @escaping () async -> Void) {
        stopListening()
        let root = db.collection("restaurants").document(restaurantID)
        changeListener = root.addSnapshotListener { [weak self] snapshot, _ in
            guard let self,
                  let data = snapshot?.data(),
                  let updatedBy = data["lastUpdatedByDevice"] as? String,
                  updatedBy != self.deviceID,
                  snapshot?.metadata.isFromCache == false      // came from server
            else { return }
            Task { await onRemoteChange() }
        }
    }

    func stopListening() {
        changeListener?.remove()
        changeListener = nil
    }

    // ── Change restaurant ID (join another device) ─────────────────────────
    /// Switches this device to sync against the given restaurantID.
    func setRestaurantID(_ id: String) {
        stopListening()
        UserDefaults.standard.set(id, forKey: restaurantIDKey)
    }

    // ── Auth ──────────────────────────────────────────────────────────────
    func signInAnonymouslyIfNeeded() async throws {
        if Auth.auth().currentUser == nil {
            _ = try await Auth.auth().signInAnonymously()
        }
    }

    // ── Member registration ───────────────────────────────────────────────
    /// Registers the current device's Firebase UID in the restaurant's
    /// members sub-collection. Security rules require this before any read/write.
    func registerAsMember() async throws {
        try await signInAnonymouslyIfNeeded()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let memberRef = db
            .collection("restaurants").document(restaurantID)
            .collection("members").document(uid)
        // merge: true so we don't overwrite joinedAt written by Cloud Function
        try await memberRef.setData(["uid": uid, "deviceID": deviceID], merge: true)
    }

    // ── Real-time employee listener ───────────────────────────────────────
    private var employeeListener: ListenerRegistration?

    /// Starts a real-time listener on the employees sub-collection.
    /// `onUpdate` is called with the fresh list whenever Firestore changes.
    func startEmployeeListener(onUpdate: @escaping ([Employee]) -> Void) {
        stopEmployeeListener()
        let col = db.collection("restaurants").document(restaurantID).collection("employees")
        employeeListener = col.addSnapshotListener { snapshot, error in
            guard let snapshot, error == nil else { return }
            let employees = snapshot.documents.compactMap { try? $0.data(as: Employee.self) }
            DispatchQueue.main.async { onUpdate(employees) }
        }
    }

    func stopEmployeeListener() {
        employeeListener?.remove()
        employeeListener = nil
    }

    // ── Upload ────────────────────────────────────────────────────────────
    func uploadAll(
        dishes:              [Dish],
        inventoryItems:      [InventoryItem],
        deliveries:          [Delivery],
        writeOffs:           [WriteOff],
        productions:         [Production],
        employees:           [Employee],
        profile:             UserProfile,
        reservations:        [TableReservation],
        suppliers:           [Supplier],
        kitchenOrders:       [KitchenOrder],
        closedKitchenOrders: [KitchenOrder],
        sales:               [Sale],
        operatingExpenses:   [OperatingExpense],
        auditRecords:        [InventoryAuditRecord]
    ) async throws {
        try await signInAnonymouslyIfNeeded()

        let root = db.collection("restaurants").document(restaurantID)

        // Upload all subcollections FIRST
        try await uploadCollection(dishes,              to: root.collection("dishes"))
        try await uploadCollection(inventoryItems,      to: root.collection("inventory"))
        try await uploadCollection(deliveries,          to: root.collection("deliveries"))
        try await uploadCollection(writeOffs,           to: root.collection("writeOffs"))
        try await uploadCollection(productions,         to: root.collection("productions"))
        try await uploadCollection(employees,           to: root.collection("employees"))
        try await uploadCollection(reservations,        to: root.collection("reservations"))
        try await uploadCollection(suppliers,           to: root.collection("suppliers"))
        try await uploadCollection(kitchenOrders,       to: root.collection("kitchenOrders"))
        try await uploadCollection(closedKitchenOrders, to: root.collection("closedKitchenOrders"))
        try await uploadCollection(sales,               to: root.collection("sales"))
        try await uploadCollection(operatingExpenses,   to: root.collection("operatingExpenses"))
        try await uploadCollection(auditRecords,        to: root.collection("auditRecords"))
        try root.collection("profile").document("current").setData(from: profile)

        // Touch root doc LAST — this triggers the real-time listener on other
        // devices only after all subcollection data is already written.
        try await root.setData([
            "restaurantID":        restaurantID,
            "lastUpdatedByDevice": deviceID,
            "updatedAt":           FieldValue.serverTimestamp()
        ], merge: true)
    }

    // ── Fast per-document kitchen order ops (no 4 s debounce) ────────────
    func uploadKitchenOrder(_ order: KitchenOrder) async throws {
        try await signInAnonymouslyIfNeeded()
        let col = db.collection("restaurants").document(restaurantID).collection("kitchenOrders")
        try col.document(order.id.uuidString).setData(from: order)
    }

    func deleteKitchenOrder(id: UUID) async throws {
        try await signInAnonymouslyIfNeeded()
        let col = db.collection("restaurants").document(restaurantID).collection("kitchenOrders")
        try await col.document(id.uuidString).delete()
    }

    func uploadClosedKitchenOrder(_ order: KitchenOrder) async throws {
        try await signInAnonymouslyIfNeeded()
        let col = db.collection("restaurants").document(restaurantID).collection("closedKitchenOrders")
        try col.document(order.id.uuidString).setData(from: order)
    }

    // ── Real-time kitchen orders listener ─────────────────────────────────
    private var kitchenOrdersListener: ListenerRegistration?

    func startKitchenOrdersListener(onUpdate: @escaping ([KitchenOrder]) -> Void) {
        kitchenOrdersListener?.remove()
        let col = db.collection("restaurants").document(restaurantID).collection("kitchenOrders")
        kitchenOrdersListener = col.addSnapshotListener { snapshot, error in
            guard let snapshot, error == nil,
                  snapshot.metadata.isFromCache == false else { return }
            let orders = snapshot.documents.compactMap { try? $0.data(as: KitchenOrder.self) }
            DispatchQueue.main.async { onUpdate(orders) }
        }
    }

    func stopKitchenOrdersListener() {
        kitchenOrdersListener?.remove()
        kitchenOrdersListener = nil
    }

    // ── Download ──────────────────────────────────────────────────────────
    func downloadAll() async throws -> ChefProCloudData {
        try await signInAnonymouslyIfNeeded()

        let root = db.collection("restaurants").document(restaurantID)

        async let dishes:              [Dish]                  = downloadCollection(from: root.collection("dishes"))
        async let inventoryItems:      [InventoryItem]         = downloadCollection(from: root.collection("inventory"))
        async let deliveries:          [Delivery]              = downloadCollection(from: root.collection("deliveries"))
        async let writeOffs:           [WriteOff]              = downloadCollection(from: root.collection("writeOffs"))
        async let productions:         [Production]            = downloadCollection(from: root.collection("productions"))
        async let employees:           [Employee]              = downloadCollection(from: root.collection("employees"))
        async let reservations:        [TableReservation]      = downloadCollection(from: root.collection("reservations"))
        async let suppliers:           [Supplier]              = downloadCollection(from: root.collection("suppliers"))
        async let kitchenOrders:       [KitchenOrder]          = downloadCollection(from: root.collection("kitchenOrders"))
        async let closedKitchenOrders: [KitchenOrder]          = downloadCollection(from: root.collection("closedKitchenOrders"))
        async let sales:               [Sale]                  = downloadCollection(from: root.collection("sales"))
        async let operatingExpenses:   [OperatingExpense]      = downloadCollection(from: root.collection("operatingExpenses"))
        async let auditRecords:        [InventoryAuditRecord]  = downloadCollection(from: root.collection("auditRecords"))

        let profileSnap = try? await root.collection("profile").document("current").getDocument()
        let profile     = try? profileSnap?.data(as: UserProfile.self)

        return try await ChefProCloudData(
            dishes:              dishes,
            inventoryItems:      inventoryItems,
            deliveries:          deliveries,
            writeOffs:           writeOffs,
            productions:         productions,
            employees:           employees,
            profile:             profile,
            reservations:        reservations,
            suppliers:           suppliers,
            kitchenOrders:       kitchenOrders,
            closedKitchenOrders: closedKitchenOrders,
            sales:               sales,
            operatingExpenses:   operatingExpenses,
            auditRecords:        auditRecords
        )
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    private func uploadCollection<T: Codable & Identifiable>(
        _ items: [T],
        to collection: CollectionReference
    ) async throws where T.ID == UUID {
        guard !items.isEmpty else { return }
        let batch = db.batch()
        for item in items {
            let doc = collection.document(item.id.uuidString)
            try batch.setData(from: item, forDocument: doc, merge: true)
        }
        try await batch.commit()
    }

    private func downloadCollection<T: Codable>(from collection: CollectionReference) async throws -> [T] {
        let snapshot = try await collection.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }
}

// MARK: - Cloud data bag

struct ChefProCloudData {
    var dishes:              [Dish]
    var inventoryItems:      [InventoryItem]
    var deliveries:          [Delivery]
    var writeOffs:           [WriteOff]
    var productions:         [Production]
    var employees:           [Employee]
    var profile:             UserProfile?
    var reservations:        [TableReservation]
    var suppliers:           [Supplier]
    var kitchenOrders:       [KitchenOrder]
    var closedKitchenOrders: [KitchenOrder]
    var sales:               [Sale]
    var operatingExpenses:   [OperatingExpense]
    var auditRecords:        [InventoryAuditRecord]
}
