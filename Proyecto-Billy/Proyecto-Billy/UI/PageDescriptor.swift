import UIKit

struct PageDescriptor {
    let title: String
    let shortTitle: String
    let iconName: String
    let message: String

    static let mainPages: [PageDescriptor] = [
        PageDescriptor(
            title: "Resumen",
            shortTitle: "Resumen",
            iconName: "chart.pie.fill",
            message: "Aquí visualizarás el total mensual, las categorías principales y las métricas de tus gastos."
        ),
        PageDescriptor(
            title: "Gastos",
            shortTitle: "Gastos",
            iconName: "list.bullet.rectangle.fill",
            message: "Desde esta sección podrás registrar, consultar y eliminar tus movimientos guardados en Core Data."
        ),
        PageDescriptor(
            title: "Servicios",
            shortTitle: "Servicios",
            iconName: "cloud.fill",
            message: "Aquí se integrarán el tipo de cambio mediante REST y el respaldo en Firebase Realtime Database."
        ),
        PageDescriptor(
            title: "Herramientas",
            shortTitle: "Extras",
            iconName: "wrench.and.screwdriver.fill",
            message: "Esta página reunirá autenticación local, notificaciones y exportación de movimientos."
        )
    ]
}
