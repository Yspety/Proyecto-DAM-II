# Proyecto DAM II — Gestor de datos personales

Aplicación móvil para iOS desarrollada con Swift, UIKit e Interface Builder mediante `Main.storyboard`. Permite registrar, organizar y proteger datos personales e integra persistencia local, servicios REST, sincronización con Firebase y herramientas nativas de iOS.

## Meta del proyecto

La meta es ofrecer una aplicación sencilla y segura para gestionar perfiles personales desde un iPhone o iPad. Cada usuario puede almacenar información de contacto, consultar sus registros sin conexión y respaldarlos en la nube mediante una cuenta autenticada.

El proyecto también busca demostrar la aplicación práctica de los temas del curso de Desarrollo de Aplicaciones Móviles II:

- Swift, UIKit, Storyboard, Auto Layout, outlets y actions.
- Navegación entre pantallas.
- UITableView y UICollectionView.
- Core Data.
- Concurrencia con async/await y actores.
- Consumo de servicios REST.
- Firebase Authentication y Cloud Firestore.
- UIPageViewController.
- UIKit Dynamics.
- Face ID o Touch ID.
- Cámara, galería y opciones nativas para compartir.

## Funcionamiento principal

La aplicación está organizada en cuatro secciones navegables:

### Resumen

Presenta indicadores generales de los perfiles registrados. Utiliza `UICollectionView` para mostrar métricas y UIKit Dynamics para incorporar una interacción visual nativa.

### Perfiles

Permite realizar las operaciones principales sobre los datos personales:

- Registrar un perfil.
- Consultar la lista de perfiles.
- Editar información existente.
- Eliminar perfiles.
- Buscar por nombre, DNI, teléfono o correo.
- Filtrar perfiles completos e incompletos.
- Ordenar por apellido o fecha de actualización.
- Agregar una fotografía desde la cámara o galería.
- Compartir la información mediante la hoja nativa de iOS.

Los datos se almacenan localmente con Core Data. Las fotografías se guardan como archivos protegidos y se relacionan con el UUID del perfil.

### Servicios

Incluye las integraciones externas del proyecto:

- Consulta de países mediante la API REST de World Bank.
- Búsqueda asíncrona con cancelación y caché local.
- Respaldo y recuperación de perfiles con Cloud Firestore.
- Separación de los datos remotos mediante el UID del usuario autenticado.

### Cuenta

Administra el acceso a Firebase:

- Sesión anónima inicial.
- Registro con correo y contraseña.
- Vinculación de una sesión anónima con una cuenta permanente.
- Inicio y cierre de sesión.
- Eliminación de la cuenta y su respaldo remoto.
- Eliminación independiente de los datos guardados en el dispositivo.

## Seguridad y privacidad

El proyecto incorpora las siguientes medidas:

- Bloqueo de acceso con Face ID, Touch ID u Optic ID.
- Ocultamiento de la interfaz cuando la aplicación pasa a segundo plano.
- Protección completa de los archivos locales mientras el dispositivo está bloqueado.
- Fotografías excluidas de las copias de seguridad del sistema.
- Reglas de Firestore que limitan el acceso al propietario de los datos.
- Confirmaciones antes de eliminar información local o remota.
- Contraseñas administradas exclusivamente por Firebase Authentication.

## Tecnologías

- Swift 5.
- UIKit.
- Interface Builder y `Main.storyboard`.
- Core Data.
- URLSession y Codable.
- Swift Concurrency (`async/await`, `Task` y `actor`).
- Firebase Authentication.
- Cloud Firestore.
- LocalAuthentication.
- UIImagePickerController.
- Swift Package Manager.

## Requisitos

- macOS con Xcode 26 o una versión compatible con iOS 17.
- iOS 17 o superior.
- Conexión a internet para REST, autenticación y sincronización.
- Un dispositivo compatible para probar cámara y biometría real.

## Ejecución

1. Clonar el repositorio.
2. Abrir `Proyecto-Billy/Proyecto-Billy.xcodeproj` en Xcode.
3. Abrir `Base.lproj/Main.storyboard` para revisar las escenas, navegación y conexiones visuales.
4. Esperar a que Swift Package Manager resuelva Firebase.
5. Confirmar que el target utiliza el bundle ID `com.cibertec.Proyecto-Billy`.
6. Seleccionar un simulador o dispositivo iOS.
7. Ejecutar con el botón **Run** de Xcode.

El archivo `GoogleService-Info.plist` incluido corresponde al proyecto Firebase configurado para esta aplicación. No debe publicarse en otros proyectos ni reutilizarse con un bundle ID diferente.

## Flujo de uso sugerido

1. Desbloquear la aplicación con biometría cuando esté disponible.
2. Crear o vincular una cuenta desde la sección **Cuenta**.
3. Registrar un perfil desde **Perfiles**.
4. Seleccionar un país mediante el servicio REST.
5. Agregar una fotografía si se desea.
6. Consultar las métricas en **Resumen**.
7. Ejecutar la sincronización desde **Servicios**.
8. Editar, compartir o eliminar los perfiles cuando sea necesario.

## Estado actual

Las funcionalidades principales están implementadas y el proyecto ha generado una compilación para simulador. También se validaron la sintaxis Swift, los tipos, la configuración Firebase, el modelo Core Data y la respuesta del servicio REST.

Continúan pendientes las pruebas manuales completas en simulador y dispositivo físico, especialmente para biometría, cámara, persistencia, sincronización entre cuentas y recuperación de información.

## Autor

Proyecto desarrollado para el curso de Desarrollo de Aplicaciones Móviles II.

Repositorio administrado por **Yspety**.
