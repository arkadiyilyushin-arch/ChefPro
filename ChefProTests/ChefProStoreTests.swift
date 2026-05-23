import XCTest
@testable import ChefPro

final class ChefProStoreTests: XCTestCase {

    var store: ChefProStore!

    override func setUp() {
        super.setUp()
        store = ChefProStore()
        // Clear demo data so tests work with controlled state
        store.dishes = []
        store.inventoryItems = []
        store.deliveries = []
        store.writeOffs = []
        store.productions = []
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Helper factories

    private func makeInventoryItem(
        name: String,
        quantity: Double,
        unit: String,
        pricePerUnit: Double,
        minQuantity: Double = 0
    ) -> InventoryItem {
        InventoryItem(
            name: name,
            category: "Test",
            quantity: quantity,
            unit: unit,
            minQuantity: minQuantity,
            pricePerUnit: pricePerUnit
        )
    }

    private func makeIngredient(
        productName: String,
        quantity: Double,
        unit: String,
        yieldFactor: Double = 1.0
    ) -> RecipeIngredient {
        RecipeIngredient(
            productName: productName,
            quantity: quantity,
            unit: unit,
            yieldFactor: yieldFactor
        )
    }

    private func makeDish(
        name: String = "Test Dish",
        salePrice: Double = 20.0,
        ingredients: [RecipeIngredient] = []
    ) -> Dish {
        Dish(
            name: name,
            category: "Test",
            salePrice: salePrice,
            ingredients: ingredients
        )
    }

    // MARK: - calculateDishCost Tests

    func testCalculateDishCostZeroIngredients() {
        let dish = makeDish(ingredients: [])
        store.dishes = [dish]
        let cost = store.calculateDishCost(dish)
        XCTAssertEqual(cost, 0.0, "A dish with no ingredients should have zero cost.")
    }

    func testCalculateDishCostSingleIngredient() {
        // 200g flour at 1.00/kg → 200/1000 * 1.00 = 0.20
        store.inventoryItems = [makeInventoryItem(name: "Flour", quantity: 5, unit: "кг", pricePerUnit: 1.0)]
        let ingredient = makeIngredient(productName: "Flour", quantity: 200, unit: "г")
        let dish = makeDish(ingredients: [ingredient])
        let cost = store.calculateDishCost(dish)
        XCTAssertEqual(cost, 0.20, accuracy: 0.001, "200g of flour at 1.00/kg should cost 0.20")
    }

    func testCalculateDishCostMultipleIngredients() {
        // 100g butter at 8.00/kg → 0.80
        // 50g cheese at 10.00/kg → 0.50
        // total → 1.30
        store.inventoryItems = [
            makeInventoryItem(name: "Butter", quantity: 2, unit: "кг", pricePerUnit: 8.0),
            makeInventoryItem(name: "Cheese", quantity: 2, unit: "кг", pricePerUnit: 10.0)
        ]
        let dish = makeDish(ingredients: [
            makeIngredient(productName: "Butter", quantity: 100, unit: "г"),
            makeIngredient(productName: "Cheese", quantity: 50, unit: "г")
        ])
        let cost = store.calculateDishCost(dish)
        XCTAssertEqual(cost, 1.30, accuracy: 0.001, "100g butter + 50g cheese should total 1.30")
    }

    func testCalculateDishCostYieldFactor() {
        // yieldFactor=0.8: rawQty = qty / yieldFactor = 0.2 / 0.8 = 0.25 kg
        // 0.25 kg at 4.00/kg → 1.00
        store.inventoryItems = [makeInventoryItem(name: "Meat", quantity: 5, unit: "кг", pricePerUnit: 4.0)]
        let ingredient = makeIngredient(productName: "Meat", quantity: 200, unit: "г", yieldFactor: 0.8)
        // rawQty = 200 / 0.8 = 250g = 0.25 kg; cost = 0.25 * 4.00 = 1.00
        let dish = makeDish(ingredients: [ingredient])
        let cost = store.calculateDishCost(dish)
        XCTAssertEqual(cost, 1.0, accuracy: 0.001, "200g at yieldFactor 0.8 should use rawQty=250g, costing 1.00")
    }

    func testCalculateDishCostYieldFactorOne() {
        // yieldFactor=1.0: no adjustment, rawQty = 200g
        store.inventoryItems = [makeInventoryItem(name: "Salt", quantity: 1, unit: "кг", pricePerUnit: 2.0)]
        let ingredient = makeIngredient(productName: "Salt", quantity: 200, unit: "г", yieldFactor: 1.0)
        let dish = makeDish(ingredients: [ingredient])
        let cost = store.calculateDishCost(dish)
        XCTAssertEqual(cost, 0.40, accuracy: 0.001, "200g at yieldFactor 1.0 should use rawQty=200g, costing 0.40")
    }

    func testCalculateDishCostZeroPriceIngredient() {
        store.inventoryItems = [makeInventoryItem(name: "Water", quantity: 10, unit: "л", pricePerUnit: 0.0)]
        let ingredient = makeIngredient(productName: "Water", quantity: 0.5, unit: "л")
        let dish = makeDish(ingredients: [ingredient])
        let cost = store.calculateDishCost(dish)
        XCTAssertEqual(cost, 0.0, accuracy: 0.001, "An ingredient with zero price should contribute zero cost.")
    }

    func testCalculateDishCostMissingInventoryItemIgnored() {
        // If inventory item not found, that ingredient is skipped (returns total unchanged)
        store.inventoryItems = []
        let ingredient = makeIngredient(productName: "Ghost Ingredient", quantity: 100, unit: "г")
        let dish = makeDish(ingredients: [ingredient])
        let cost = store.calculateDishCost(dish)
        XCTAssertEqual(cost, 0.0, "Missing inventory items should be skipped, keeping cost at 0.")
    }

    func testCalculateDishCostCaseInsensitiveMatch() {
        store.inventoryItems = [makeInventoryItem(name: "Tomato", quantity: 5, unit: "кг", pricePerUnit: 3.0)]
        let ingredient = makeIngredient(productName: "tomato", quantity: 500, unit: "г")
        let dish = makeDish(ingredients: [ingredient])
        let cost = store.calculateDishCost(dish)
        // 500g * (1/1000) * 3.00 = 1.50
        XCTAssertEqual(cost, 1.50, accuracy: 0.001, "Ingredient name matching should be case-insensitive.")
    }

    // MARK: - canProduce Tests

    func testCanProduceSufficientStock() {
        store.inventoryItems = [makeInventoryItem(name: "Bread", quantity: 10, unit: "шт", pricePerUnit: 0.5)]
        let dish = makeDish(ingredients: [makeIngredient(productName: "Bread", quantity: 2, unit: "шт")])
        XCTAssertTrue(store.canProduce(dish: dish, portions: 3), "Should be able to produce 3 portions (needs 6 units, has 10).")
    }

    func testCanProduceInsufficientStock() {
        store.inventoryItems = [makeInventoryItem(name: "Bread", quantity: 5, unit: "шт", pricePerUnit: 0.5)]
        let dish = makeDish(ingredients: [makeIngredient(productName: "Bread", quantity: 2, unit: "шт")])
        XCTAssertFalse(store.canProduce(dish: dish, portions: 3), "Should NOT be able to produce 3 portions (needs 6 units, has 5).")
    }

    func testCanProduceExactlyEnoughStock() {
        store.inventoryItems = [makeInventoryItem(name: "Bread", quantity: 6, unit: "шт", pricePerUnit: 0.5)]
        let dish = makeDish(ingredients: [makeIngredient(productName: "Bread", quantity: 2, unit: "шт")])
        XCTAssertTrue(store.canProduce(dish: dish, portions: 3), "Should be able to produce when stock is exactly sufficient (6 == 6).")
    }

    func testCanProduceMissingInventoryItem() {
        store.inventoryItems = []
        let dish = makeDish(ingredients: [makeIngredient(productName: "Secret Spice", quantity: 1, unit: "г")])
        XCTAssertFalse(store.canProduce(dish: dish, portions: 1), "Cannot produce if a required ingredient is not in inventory.")
    }

    func testCanProduceMultipleIngredients() {
        store.inventoryItems = [
            makeInventoryItem(name: "Pasta", quantity: 1, unit: "кг", pricePerUnit: 1.5),
            makeInventoryItem(name: "Sauce", quantity: 500, unit: "мл", pricePerUnit: 0.01)
        ]
        let dish = makeDish(ingredients: [
            makeIngredient(productName: "Pasta", quantity: 200, unit: "г"),   // needs 0.2 kg
            makeIngredient(productName: "Sauce", quantity: 100, unit: "мл")   // needs 100 ml
        ])
        // 2 portions: 0.4 kg pasta (have 1 kg) and 200 ml sauce (have 500 ml) — OK
        XCTAssertTrue(store.canProduce(dish: dish, portions: 2))
    }

    func testCanProduceMultipleIngredientsOneFails() {
        store.inventoryItems = [
            makeInventoryItem(name: "Pasta", quantity: 1, unit: "кг", pricePerUnit: 1.5),
            makeInventoryItem(name: "Sauce", quantity: 50, unit: "мл", pricePerUnit: 0.01)
        ]
        let dish = makeDish(ingredients: [
            makeIngredient(productName: "Pasta", quantity: 200, unit: "г"),
            makeIngredient(productName: "Sauce", quantity: 100, unit: "мл")   // needs 200 ml, has only 50
        ])
        XCTAssertFalse(store.canProduce(dish: dish, portions: 2), "Should fail if any single ingredient is insufficient.")
    }

    // MARK: - produceDish Tests

    func testProduceDishDecreasesInventory() {
        store.inventoryItems = [
            makeInventoryItem(name: "Rice", quantity: 5, unit: "кг", pricePerUnit: 2.0)
        ]
        let dish = makeDish(ingredients: [
            makeIngredient(productName: "Rice", quantity: 200, unit: "г")   // 0.2 kg per portion
        ])
        store.dishes = [dish]
        let success = store.produceDish(dish, portions: 2)
        XCTAssertTrue(success, "produceDish should return true when stock is available.")
        // 2 portions * 0.2 kg = 0.4 kg consumed
        let remaining = store.inventoryItems.first(where: { $0.name == "Rice" })?.quantity ?? -1
        XCTAssertEqual(remaining, 4.6, accuracy: 0.001, "Inventory should decrease by 0.4 kg after producing 2 portions.")
    }

    func testProduceDishReturnsFalseWhenCannotProduce() {
        store.inventoryItems = [
            makeInventoryItem(name: "Egg", quantity: 1, unit: "шт", pricePerUnit: 0.3)
        ]
        let dish = makeDish(ingredients: [
            makeIngredient(productName: "Egg", quantity: 2, unit: "шт")   // needs 2, has 1
        ])
        store.dishes = [dish]
        let success = store.produceDish(dish, portions: 1)
        XCTAssertFalse(success, "produceDish should return false when stock is insufficient.")
    }

    func testProduceDishInventoryUnchangedOnFailure() {
        store.inventoryItems = [
            makeInventoryItem(name: "Egg", quantity: 1, unit: "шт", pricePerUnit: 0.3)
        ]
        let dish = makeDish(ingredients: [
            makeIngredient(productName: "Egg", quantity: 3, unit: "шт")
        ])
        store.dishes = [dish]
        _ = store.produceDish(dish, portions: 1)
        let remaining = store.inventoryItems.first(where: { $0.name == "Egg" })?.quantity ?? -1
        XCTAssertEqual(remaining, 1.0, accuracy: 0.001, "Inventory must not change when production fails.")
    }

    func testProduceDishAddsProductionRecord() {
        store.inventoryItems = [
            makeInventoryItem(name: "Sugar", quantity: 2, unit: "кг", pricePerUnit: 1.0)
        ]
        let dish = makeDish(name: "Sweet Roll", ingredients: [
            makeIngredient(productName: "Sugar", quantity: 100, unit: "г")
        ])
        store.dishes = [dish]
        let before = store.productions.count
        _ = store.produceDish(dish, portions: 1)
        XCTAssertEqual(store.productions.count, before + 1, "produceDish should append a Production record.")
        XCTAssertEqual(store.productions.last?.dishName, "Sweet Roll")
    }

    func testProduceDishAddsWriteOffRecord() {
        store.inventoryItems = [
            makeInventoryItem(name: "Oil", quantity: 1, unit: "л", pricePerUnit: 5.0)
        ]
        let dish = makeDish(ingredients: [
            makeIngredient(productName: "Oil", quantity: 100, unit: "мл")
        ])
        store.dishes = [dish]
        let before = store.writeOffs.count
        _ = store.produceDish(dish, portions: 1)
        XCTAssertGreaterThan(store.writeOffs.count, before, "produceDish should append a WriteOff record for each ingredient.")
    }

    func testProduceDishReturnsFalseForZeroPortions() {
        store.inventoryItems = [makeInventoryItem(name: "Egg", quantity: 10, unit: "шт", pricePerUnit: 0.3)]
        let dish = makeDish(ingredients: [makeIngredient(productName: "Egg", quantity: 1, unit: "шт")])
        let success = store.produceDish(dish, portions: 0)
        XCTAssertFalse(success, "produceDish should return false for 0 portions.")
    }

    func testProduceDishMultiplePortions() {
        store.inventoryItems = [
            makeInventoryItem(name: "Chicken", quantity: 3, unit: "кг", pricePerUnit: 7.0),
            makeInventoryItem(name: "Lemon", quantity: 10, unit: "шт", pricePerUnit: 0.5)
        ]
        let dish = makeDish(ingredients: [
            makeIngredient(productName: "Chicken", quantity: 300, unit: "г"),  // 0.3 kg/portion
            makeIngredient(productName: "Lemon", quantity: 1, unit: "шт")
        ])
        store.dishes = [dish]
        let success = store.produceDish(dish, portions: 5)
        XCTAssertTrue(success)
        // Chicken: 3 - (0.3 * 5) = 1.5 kg
        let chicken = store.inventoryItems.first(where: { $0.name == "Chicken" })?.quantity ?? -1
        XCTAssertEqual(chicken, 1.5, accuracy: 0.001)
        // Lemon: 10 - 5 = 5
        let lemon = store.inventoryItems.first(where: { $0.name == "Lemon" })?.quantity ?? -1
        XCTAssertEqual(lemon, 5, accuracy: 0.001)
    }

    // MARK: - addDelivery Tests

    func testAddDeliveryIncreasesExistingInventory() {
        store.inventoryItems = [
            makeInventoryItem(name: "Milk", quantity: 5, unit: "л", pricePerUnit: 1.2)
        ]
        let delivery = Delivery(
            supplier: "Dairy Co",
            productName: "Milk",
            quantity: 10,
            unit: "л",
            price: 12.0,   // 1.20/л
            date: Date(),
            acceptedBy: "Test"
        )
        store.addDelivery(delivery)
        let item = store.inventoryItems.first(where: { $0.name == "Milk" })
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.quantity ?? 0, 15.0, accuracy: 0.001, "Delivery of 10 L should add to existing 5 L, totalling 15 L.")
    }

    func testAddDeliveryCreatesNewInventoryItemWhenNotFound() {
        store.inventoryItems = []
        let delivery = Delivery(
            supplier: "New Supplier",
            productName: "Truffle Oil",
            quantity: 2,
            unit: "л",
            price: 60.0,
            date: Date(),
            acceptedBy: "Test"
        )
        store.addDelivery(delivery)
        let item = store.inventoryItems.first(where: { $0.name.lowercased() == "truffle oil" })
        XCTAssertNotNil(item, "addDelivery should create a new inventory item if the product is not found.")
        XCTAssertEqual(item?.quantity ?? 0, 2.0, accuracy: 0.001)
    }

    func testAddDeliveryAppendsToDeliveriesList() {
        let before = store.deliveries.count
        let delivery = Delivery(
            supplier: "Test Supplier",
            productName: "Olive Oil",
            quantity: 5,
            unit: "л",
            price: 25.0,
            date: Date(),
            acceptedBy: "Test"
        )
        store.addDelivery(delivery)
        XCTAssertEqual(store.deliveries.count, before + 1, "addDelivery should append the delivery to the deliveries list.")
    }

    func testAddDeliveryUpdatesWeightedAveragePrice() {
        // Existing: 10 kg at 2.00 = value 20.0
        // Delivery: 10 kg at 3.00 (price=30 total) = value 30.0
        // New avg: (20 + 30) / 20 = 2.50
        store.inventoryItems = [
            makeInventoryItem(name: "Flour", quantity: 10, unit: "кг", pricePerUnit: 2.0)
        ]
        let delivery = Delivery(
            supplier: "Mill",
            productName: "Flour",
            quantity: 10,
            unit: "кг",
            price: 30.0,   // 3.00/кг
            date: Date(),
            acceptedBy: "Test"
        )
        store.addDelivery(delivery)
        let item = store.inventoryItems.first(where: { $0.name == "Flour" })
        XCTAssertEqual(item?.pricePerUnit ?? 0, 2.50, accuracy: 0.001, "Price should be weighted average of existing and delivered stock.")
    }

    func testAddDeliveryWithZeroQuantityDoesNotCrash() {
        let delivery = Delivery(
            supplier: "Supplier",
            productName: "Mystery",
            quantity: 0,
            unit: "шт",
            price: 0,
            date: Date(),
            acceptedBy: "Test"
        )
        // Should not crash; just adds delivery record
        store.addDelivery(delivery)
        XCTAssertEqual(store.deliveries.count, 1)
    }

    func testAddDeliveryMultipleDeliveriesAccumulate() {
        store.inventoryItems = [
            makeInventoryItem(name: "Salt", quantity: 2, unit: "кг", pricePerUnit: 0.5)
        ]
        let d1 = Delivery(supplier: "S1", productName: "Salt", quantity: 3, unit: "кг", price: 1.5, date: Date(), acceptedBy: "T")
        let d2 = Delivery(supplier: "S2", productName: "Salt", quantity: 5, unit: "кг", price: 2.5, date: Date(), acceptedBy: "T")
        store.addDelivery(d1)
        store.addDelivery(d2)
        let item = store.inventoryItems.first(where: { $0.name == "Salt" })
        XCTAssertEqual(item?.quantity ?? 0, 10.0, accuracy: 0.001, "Two deliveries of 3 + 5 kg should add to existing 2 kg = 10 kg total.")
    }
}
