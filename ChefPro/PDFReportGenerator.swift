import SwiftUI
import UIKit

// MARK: - PDF Reports

enum ChefPDFReportType: String, CaseIterable, Identifiable {
    case writeOffs = "Списания"
    case foodCost = "Food Cost"
    case inventory = "Инвентаризация"
    case deliveries = "Приемка товара"

    var id: String { rawValue }
}

final class PDFReportGenerator {
    static func createReport(type: ChefPDFReportType, store: ChefProStore) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let fileName = "ChefPro_\(type.rawValue.replacingOccurrences(of: " ", with: "_")).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()

                var y: CGFloat = 40

                func draw(_ text: String, size: CGFloat = 14, bold: Bool = false) {
                    let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                    let attrs: [NSAttributedString.Key: Any] = [.font: font]
                    text.draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
                    y += size + 12
                }

                draw("ChefPro", size: 28, bold: true)
                draw(type.rawValue, size: 22, bold: true)
                draw("Дата: \(Date().formatted(date: .abbreviated, time: .shortened))", size: 12)
                y += 10

                switch type {
                case .writeOffs:
                    draw("Списания", size: 18, bold: true)
                    if store.writeOffs.isEmpty {
                        draw("Списаний пока нет.")
                    } else {
                        for item in store.writeOffs.reversed() {
                            draw("• \(item.productName) — \(item.quantity) \(item.unit), причина: \(item.reason), сотрудник: \(item.employee)")
                            if y > 780 {
                                context.beginPage()
                                y = 40
                            }
                        }
                    }

                case .foodCost:
                    draw("Food Cost по блюдам", size: 18, bold: true)
                    for dish in store.dishes {
                        let cost = store.calculateDishCost(dish)
                        let percent = store.foodCostPercent(dish)
                        draw("• \(dish.name): себестоимость \(String(format: "%.2f", cost)), цена \(String(format: "%.2f", dish.salePrice)), food cost \(String(format: "%.1f", percent))%")
                        if y > 780 {
                            context.beginPage()
                            y = 40
                        }
                    }

                case .inventory:
                    draw("Инвентаризация", size: 18, bold: true)
                    for item in store.inventoryItems {
                        let status = item.isLowStock ? "Нужно заказать" : "В норме"
                        draw("• \(item.name): \(String(format: "%.1f", item.quantity)) \(item.unit), мин. \(String(format: "%.1f", item.minQuantity)), цена \(String(format: "%.2f", item.pricePerUnit)), \(status)")
                        if y > 780 {
                            context.beginPage()
                            y = 40
                        }
                    }

                case .deliveries:
                    draw("Приемка товара", size: 18, bold: true)
                    if store.deliveries.isEmpty {
                        draw("Приемок пока нет.")
                    } else {
                        for item in store.deliveries.reversed() {
                            draw("• \(item.productName): \(item.quantity) \(item.unit), поставщик: \(item.supplier), сумма: \(String(format: "%.2f", item.price)), принял: \(item.acceptedBy)")
                            if y > 780 {
                                context.beginPage()
                                y = 40
                            }
                        }
                    }
                }
            }

            return url
        } catch {
            return nil
        }
    }

    static func createTechCardPDF(dish: Dish, store: ChefProStore) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let safeName = dish.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TechCard_\(safeName).pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = 40

                func draw(_ text: String, size: CGFloat = 12, bold: Bool = false, x: CGFloat = 40) {
                    let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                    let attrs: [NSAttributedString.Key: Any] = [.font: font]
                    let str = text as NSString
                    let maxW = pageRect.width - x - 40
                    let rect = CGRect(x: x, y: y, width: maxW, height: 200)
                    str.draw(in: rect, withAttributes: attrs)
                    let h = str.boundingRect(with: CGSize(width: maxW, height: .greatestFiniteMagnitude),
                                             options: .usesLineFragmentOrigin, attributes: attrs, context: nil).height
                    y += h + 8
                }

                func line() {
                    UIColor.lightGray.setStroke()
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: 40, y: y))
                    path.addLine(to: CGPoint(x: 555, y: y))
                    path.stroke()
                    y += 8
                }

                // Photo if available
                if let photo = store.loadDishPhoto(for: dish) {
                    let imgRect = CGRect(x: 40, y: y, width: 515, height: 160)
                    photo.draw(in: imgRect)
                    y += 170
                }

                draw("ТЕХНОЛОГИЧЕСКАЯ КАРТА", size: 18, bold: true)
                draw("Ресторан: \(store.restaurantName)", size: 11)
                draw("Дата: \(Date().formatted(date: .abbreviated, time: .shortened))", size: 11)
                y += 6; line()

                draw(dish.name, size: 22, bold: true)
                draw("Категория: \(dish.category)", size: 12)
                if dish.cookTime > 0 { draw("Время готовки: \(dish.cookTime) мин", size: 12) }
                draw("Цена продажи: \(String(format: "%.2f", dish.salePrice))", size: 12)
                let cost = store.calculateDishCost(dish)
                let fc   = store.foodCostPercent(dish)
                draw("Себестоимость: \(String(format: "%.2f", cost))  |  Food cost: \(String(format: "%.1f", fc))%", size: 12)
                draw("Статус: \(dish.menuStatus.rawValue)", size: 12)
                if !dish.allergens.isEmpty { draw("Аллергены: \(dish.allergens.joined(separator: ", "))", size: 12) }
                y += 6; line()

                draw("ИНГРЕДИЕНТЫ", size: 14, bold: true)
                y += 4
                // Header
                let colX: [CGFloat] = [40, 220, 310, 400, 490]
                func drawRow(_ cols: [String], bold: Bool = false) {
                    for (i, text) in cols.enumerated() {
                        let font = bold ? UIFont.boldSystemFont(ofSize: 10) : UIFont.systemFont(ofSize: 10)
                        text.draw(at: CGPoint(x: colX[i], y: y), withAttributes: [.font: font])
                    }
                    y += 18
                }
                drawRow(["Продукт", "Кол-во (норм.)", "Ед.", "Потери %", "Себест."], bold: true)
                line()

                for ing in dish.ingredients {
                    if y > 780 { ctx.beginPage(); y = 40 }
                    let lossStr = ing.yieldFactor < 1.0 ? "\(Int((1 - ing.yieldFactor) * 100))%" : "—"
                    var ingCost = ""
                    if let item = store.inventoryItems.first(where: { $0.name.lowercased() == ing.productName.lowercased() }) {
                        let rawQty = ing.yieldFactor > 0 ? ing.quantity / ing.yieldFactor : ing.quantity
                        let conv   = store.convert(quantity: rawQty, from: ing.unit, to: item.unit)
                        ingCost    = String(format: "%.2f", conv * item.pricePerUnit)
                    }
                    drawRow([ing.productName,
                             String(format: "%.1f", ing.quantity),
                             ing.unit,
                             lossStr,
                             ingCost])
                }

                y += 10; line()
                draw("Итого себестоимость: \(String(format: "%.2f", cost))", size: 12, bold: true)
                draw("Food cost: \(String(format: "%.1f", fc))%", size: 12, bold: true)

                // Steps
                if !dish.steps.isEmpty {
                    y += 14; line()
                    draw("ШАГИ ПРИГОТОВЛЕНИЯ", size: 14, bold: true)
                    y += 4
                    for step in dish.steps {
                        if y > 740 { ctx.beginPage(); y = 40 }
                        // Step photo
                        if let img = store.loadStepPhoto(for: step) {
                            let imgRect = CGRect(x: 40, y: y, width: 515, height: 120)
                            img.draw(in: imgRect)
                            y += 128
                        }
                        draw("Шаг \(step.stepNumber)\(step.durationMinutes > 0 ? " (\(step.durationMinutes) мин)" : "")", size: 11, bold: true)
                        draw(step.instruction, size: 10)
                        if !step.tip.isEmpty { draw("💡 \(step.tip)", size: 10) }
                        y += 4
                    }
                }

                y += 20
                draw("Подпись шеф-повара: _______________________________", size: 11)
            }
            return url
        } catch {
            return nil
        }
    }
}
