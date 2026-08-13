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
            message: "Aquí visualizarás métricas y el estado general de tus perfiles personales."
        ),
        PageDescriptor(
            title: "Perfiles",
            shortTitle: "Perfiles",
            iconName: "person.text.rectangle.fill",
            message: "Desde esta sección podrás registrar, consultar, editar y eliminar perfiles personales guardados en Core Data."
        ),
        PageDescriptor(
            title: "Servicios",
            shortTitle: "Servicios",
            iconName: "cloud.fill",
            message: "Aquí se integrarán servicios REST y el respaldo seguro de perfiles mediante Firebase."
        ),
        PageDescriptor(
            title: "Cuenta",
            shortTitle: "Cuenta",
            iconName: "person.badge.key.fill",
            message: "Administra el acceso y protege el respaldo de tus perfiles."
        )
    ]
}
