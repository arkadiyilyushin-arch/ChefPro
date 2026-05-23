import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ChefProFirebaseService: ObservableObject {
    static let shared = ChefProFirebaseService()

    private let db = Firestore.firestore()
    private let restaurantIDKey = "chefpro_restaurant_id"

    var restaurantID: String {
        if let saved = UserDefaults.standard.string(forKey: restaurantIDKey) {
            return saved
        }

        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: restaurantIDKey)
        return newID
    }

    private init() {}

    func signInAnonymouslyIfNeeded() async throws {
        if Auth.auth().currentUser == nil {
            _ = try await Auth.auth().signInAnonymously()
        }
    }

    func uploadAll(
        dishes: [Dish],
        inventoryItems: [InventoryItem],
        deliveries: [Delivery],
        writeOffs: [WriteOff],
        productions: [Production],
        employees: [Employee],
        profile: UserProfile
    ) async throws {
        try await signInAnonymouslyIfNeeded()

        let root = db.collection("restaurants").document(restaurantID)

        try await root.setData([
            "restaurantID": restaurantID,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        try await uploadCollection(dishes, to: root.collection("dishes"))
        try await uploadCollection(inventoryItems, to: root.collection("inventory"))
        try await uploadCollection(deliveries, to: root.collection("deliveries"))
        try await uploadCollection(writeOffs, to: root.collection("writeOffs"))
        try await uploadCollection(productions, to: root.collection("productions"))
        try await uploadCollection(employees, to: root.collection("employees"))
        try root.collection("profile").document("current").setData(from: profile)
    }

    func downloadAll() async throws -> ChefProCloudData {
        try await signInAnonymouslyIfNeeded()

        let root = db.collection("restaurants").document(restaurantID)

        async let dishes: [Dish] = downloadCollection(from: root.collection("dishes"))
        async let inventoryItems: [InventoryItem] = downloadCollection(from: root.collection("inventory"))
        async let deliveries: [Delivery] = downloadCollection(from: root.collection("deliveries"))
        async let writeOffs: [WriteOff] = downloadCollection(from: root.collection("writeOffs"))
        async let productions: [Production] = downloadCollection(from: root.collection("productions"))
        async let employees: [Employee] = downloadCollection(from: root.collection("employees"))

        let profileSnapshot = try? await root.collection("profile").document("current").getDocument()
        let profile = try? profileSnapshot?.data(as: UserProfile.self)

        return try await ChefProCloudData(
            dishes: dishes,
            inventoryItems: inventoryItems,
            deliveries: deliveries,
            writeOffs: writeOffs,
            productions: productions,
            employees: employees,
            profile: profile
        )
    }

    private func uploadCollection<T: Codable & Identifiable>(_ items: [T], to collection: CollectionReference) async throws where T.ID == UUID {
        let batch = db.batch()

        for item in items {
            let doc = collection.document(item.id.uuidString)
            try batch.setData(from: item, forDocument: doc, merge: true)
        }

        try await batch.commit()
    }

    private func downloadCollection<T: Codable>(from collection: CollectionReference) async throws -> [T] {
        let snapshot = try await collection.getDocuments()
        return snapshot.documents.compactMap { document in
            try? document.data(as: T.self)
        }
    }
}

struct ChefProCloudData {
    var dishes: [Dish]
    var inventoryItems: [InventoryItem]
    var deliveries: [Delivery]
    var writeOffs: [WriteOff]
    var productions: [Production]
    var employees: [Employee]
    var profile: UserProfile?
}
