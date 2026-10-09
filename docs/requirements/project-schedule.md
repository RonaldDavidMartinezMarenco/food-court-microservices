# BACKLOG

| SEMANA | # HU | Rol | Historia de Usuario | Descripcion | Criterios de aceptacion |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | Cliente | Crear Propietario | Yo como Administrador de la plataforma de plazoleta de comidas<br>necesito poder crear en el sistema la cuenta para un propietario<br>para poder crear un restaurante a cargo de un propietario | 1. Al crear una cuenta, se deben solicitar los siguientes campos obligatorios:<br>Nombre, Apellido, DocumentoDeIdentidad, celular, fechaNacimiento, correo y clave(encriptada con bcrypt)<br>2. Se debe verificar estructura de email válida, el teléfono debe contener un máximo de 13 caracteres y puede contener el símbolo +. Ejemplo: +573005698325, El documento de identidad debe ser únicamente numérico.<br>3. El usuario quedara con el rol propietario.<br>4. El usuario debe ser mayor de edad |
| 1 | 2 | Administrador | Crear Restaurante | Yo como administrador de la plazoleta de comidas<br>necesito poder crear en el sistema los restaurantes<br>para brindarle al cliente la posibilidad de escoger en cual pedir sus alimentos. | 1. La creación de un restaurante requiere los siguientes campos obligatorios:<br>Nombre, NIT, Direccion, Telefono, UrlLogo y el id del usuario propitario.<br>2. Al momento de la creación del restaurante, se debe validar que el el id del usuario corresponda a un usuario con ese rol.<br>3. Los campos NIT y TelefonoRestaurante deben ser únicamente numéricos. El campo TelefonoRestaurante debe contener un máximo de 13 caracteres y puede contener el símbolo +. Ejemplo: +573005698325.<br>4. El nombre del restaurante puede contener números, pero no se permiten nombres con sólo números. |
| 1 | 3 | Propietario | Crear Plato. | Yo como propietario de un restaurante<br>necesito crear platos para asociarlos al menú de mi restaurante<br>para brindarle diferentes opciones de platos al cliente | 1. Solo el propietario de un restaurante puede crear platos.<br>2. Para crear un plato se deben solicitar los siguientes campos obligatorios:<br>Nombre del plato, precio del plato (en números enteros positivos y mayores a 0), Descripción, UrlImagen y la categoria.<br>3. Todo plato debe estar asociado a un restaurante.<br>4. por defecto cada plato recien creado tiene la variable activa en true.  |
| 1 | 4 | Propietario | Modificar Plato. | Yo como propietario de un restaurante<br>necesito actualizar la información de los platos en el menú <br>para corregir valores errados o actualizar precios | 1. Solo se puede modificar precio y descripcion. |
| 1 | 5 | Administrador / Propietario / Empleado | Agregar Autenticacion al sistema | Yo como administrador / cliente / propietario / empleado<br>necesito agregar la autenticacion al sistema<br>para poder acceder a las funcionalidades que le corresponden a mi rol y exponer mis servicios solo a usuarios logiados | 1. El inicio de sesión es a través de correo y clave.<br>2. Se debe validar usuario y contraseña correcta.<br>3. El número de intentos puede ser ilimitado.<br>4. Una vez iniciada la sesión, se debe garantizar que con esa sesión iniciada, cada usuario tiene los permisos para realizar las acciones que le correspondan a su rol.<br>5. Agregar validacion de autenticacion a los siguientes endpoint:<br>    -si creo un usuario proapietario, vlidar que la persona que llamo el servicio sera usuario administrador.<br>    -si creo un usuario empleado, validar que la persona que llamo el servicio sea usuario propietario.<br>    -si creo un restaurante, validar que la persona que llamo el servicio sea un usuario administrador.<br>    -si creo/modifico un plato, validar que la persona que llamo el servicio sea un usuario propietario y sea el propietario del restaurante al cual se le va a asignar ese plato.<br>Nota: En esta versión de la aplicación, no está contemplada la recuperación de contraseña.<br> |
| 2 | 6 | Propietario | Crear cuenta empleado | Yo como propietario de un restaurante <br>necesito poder crearles cuentas a los empleados<br>para que puedan acceder al sistema y administrar los pedidos | 1. Solo el propietario puede crearle cuentas a los empleados de su empresa<br>2. Al crear una cuenta para empleado, se deben solicitar los siguientes campos obligatorios:<br>Nombre, Apellido, DocumentoDeIdentidad, celular, correo, idRol y clave(encriptada con bcrypt).<br>3. El usuario quedara con el rol empleado. |
| 2 | 7 | Propietario | Habilitar/Deshabilitar Plato | Yo como propietario de un restaurante<br>necesito activar/desactivar platos en el menú <br>para dejar de ofrecer el producto en el menú | 1. Solo el propietario puede habilitar/deshabilitar platos.<br>2. No se permiten modificar platos de otros restaurantes diferentes al propio. |
| 2 | 8 | Cliente | Crear cuenta Cliente | Yo como cliente de la plazoleta de comida <br>necesito poder crear mi cuenta <br>para que puedan acceder al sistema y Realizar pedidos | 1. Al crear una cuenta para Cliente, se deben solicitar los siguientes campos obligatorios:<br>Nombre, Apellido, DocumentoDeIdentidad, celular, correo, idRol y clave(encriptada con bcrypt).<br>3. El usuario quedara con el rol cliente." |
| 2 | 9 | Cliente | Listar los restaurantes | Yo como cliente de la plazoleta de comidas<br>necesito listar los restaurantes disponibles<br>para poder elegir en cual deseo ordenar un plato | 1. Se deben listar todos los restaurantes por orden alfabético y paginados de acuerdo con un campo que permita especificar cuántos elementos por página.<br>2. Los campos devueltos de cada restaurante deben ser: Nombre, UrlLogo |
| 2 | 10 | Cliente | Listar los platos de un restaurante | Yo como cliente de la plazoleta de comidas<br>necesito listar el menú de cada restaurante al que le doy clic<br>para poder solicitar el plato de mi preferencia | 1. Se deben listar paginados y poderse filtrar por categoría los platos de cada menú.<br>2. Se debe poder paginar de acuerdo con el número de elementos por página escogido. |
| 2 | 11 | Cliente | Realizar pedido | Yo como cliente de la plazoleta de comidas<br>necesito poder solicitar los platos de mi preferencia<br>para que puedan prepararlos y traerlos a mi mesa | 1. Un pedido consta de una lista de platos de un mismo restaurante.<br>2, Todo pedido debe especificar el restaurante, los platos escogidos y la cantidad de cada uno de esos platos.<br>3. Inmediatamente después de recibir un pedido, este debe quedar con estado "Pendiente".<br>4. El cliente puede solicitar un nuevo pedido, solo si no tiene ningun pedido en proceso(en_preparacion,pendiente o listo) |
| 2 | 12 | Empleado | Obtener lista de pedidos filtrando por estado | Yo como empleado de un restaurante<br>necesito visualizar la lista de pedidos filtrando por estado<br>para poder seleccionar aquel pedido al que necesite cambiarle su estado | 1. El servicio debe devolver la lista de pedidos de acuerdo con un filtro por estado.<br>2. El servicio debe estar paginado y se le debe especificar la cantidad de elementos por página.<br>3. Se deben listar todos los campos del pedido. <br>4. Solo se pueden listar los pedidos del restaurante al que pertenece el empleado. |
| 3 | 13 | Empleado | Asignarse a un pedido y cambiar estado a "en preparación" | Yo como empleado de un restaurante<br>necesito asignarme a un pedido y cambiarle su estado<br>para que el cliente pueda saber el avance de su orden. | 1. El servicio debe devolver la lista de pedidos de acuerdo con un filtro por estado.<br>2. El servicio debe estar paginado y se le debe especificar la cantidad de elementos por página.<br>3. Se deben listar todos los campos del pedido. <br>4. Solo se pueden listar los pedidos del restaurante al que pertenece el empleado.<br>5. Asignarse a un pedido significa que en el campo EmpleadoAsignado se pone el id de quien se asigna a ese pedido. |
| 3 | 14 | Empleado | Notificar que el pedido está listo | Yo como empleado de un restaurante<br>necesito notificar al cliente de que su pedido está listo<br>para que tenga la certeza de que en pocos minutos lo podra recoger. | 1. Cuando un pedido está listo, se le debe notificar al cliente que su pedido está listo a través de mensaje SMS al telefono indicando el pin de seguridad para reclamar su pedido. |
| 3 | 15 | Empleado | Entregar pedido (Marcarlo como entregado) | Yo como empleado de un restaurante<br>necesito marcar como entregado un pedido <br>para poder cerrar el ciclo del mismo y concentrarme en otros pedidos | 1. Sólo los pedidos que están en estado "Listo" pueden pasar a estado "entregado"<br>2. Ningún pedido en estado "entregado" puede ser modificado a cualquier estado diferente de "Listo".<br>3. Par apoder cambiar al estado "entregado" el empleado debe digitar el pin de seguridad que le fue enviado al cliente para reclamar su pedido. |
| 3 | 16 | Cliente | Cancelar pedido | Yo como cliente de un restaurante<br>necesito poder cancelar mi pedido<br>para tener la posibilidad de retractarme por cualquier motivo | 1. Sólo se pueden cancelar pedidos que se encuentren en estado "Pendiente"<br>2, Si el estado del pedido que tratan de cancelar es diferente a "Pendiente", se le debe notificar al usuario: "Lo sentimos, tu pedido ya está en preparación y no puede cancelarse" |
| 3 | 17 | Cliente | Consultar trazabilidad del pedido | Yo como cliente de un restaurate<br>necesito poder visualizar los cambios de estado de mi pedido <br>para ver la rapides del servicio solicitado. | 1. Se debe crear un registro de cada cambio de estado de un pedido <br>2. Cada cliente puede consultar el historial de logs solo de sus propios pedidos. |
| 3 | 18 | Propietario | Consultar la eficiencia de los pedidos  | Yo como propietario de un restaurante<br>necesito poder saber que eficiencia estan teniendo los pedidos del restaurante<br>para dar una mejor experiencia a los clientes | 1. mostrar de cada pedido, cual es el tiempo entre que un pedido inicia y un pedido termina<br>2. mostrar por empleado, un raking de cual es el tiempo medio entre que un pedido inicia y un pedido termina<br> |

# CONOCIMIENTOS

| # HU | Rol | Historia de Usuario | conocimientos |
| --- | --- | --- | --- |
| 1 | Cliente | Crear Propietario | {"arquitectura limpia":"3","test unitarios":"3"} |
| 2 | Administrador | Crear Restaurante | {"arquitectura limpia":"3","test unitarios":"3"} |
| 3 | Propietario | Crear Plato. | {"arquitectura limpia":"3","test unitarios":"3"} |
| 4 | Propietario | Modificar Plato. | {"arquitectura limpia":"3","test unitarios":"3"} |
| 5 | Administrador / Propietario / Empleado | Agregar Autenticacion al sistema | x |
| 6 | Propietario | Crear cuenta empleado | {"arquitectura limpia":"3","test unitarios":"3"} |
| 7 | Propietario | Habilitar/Deshabilitar Plato | x |
| 8 | Cliente | Crear cuenta Cliente | x |
| 9 | Cliente | Listar los restaurantes | {"arquitectura limpia":"3","test unitarios":"3"} |
| 10 | Cliente | Listar los platos de un restaurante | {"arquitectura limpia":"3","test unitarios":"3"} |
| 11 | Cliente | Realizar pedido | {"arquitectura limpia":"3","test unitarios":"3","conexión con otros servicios":"2"} |
| 12 | Empleado | Obtener lista de pedidos filtrando por estado | x |
| 13 | Empleado | Asignarse a un pedido y cambiar estado a "en preparación" | x |
| 14 | Empleado | Notificar que el pedido está listo | x |
| 15 | Empleado | Entregar pedido (Marcarlo como entregado) | x |
| 16 | Cliente | Cancelar pedido | x |
| 17 | Cliente | Consultar trazabilidad del pedido | {"arquitectura limpia":"3","test unitarios":"3","conexión con otros servicios":"2","microservicios":"2"} |
| 18 | Propietario | Consultar la eficiencia de los pedidos  | {"arquitectura limpia":"3","test unitarios":"3","conexión con otros servicios":"2","microservicios":"2"} |

# Mentores

| NOMBRE | CORREO | CUIDAD |
| --- | --- | --- |
| David Tolosa | david.tolosa@pragma.com.co | Cucuta |
| Pedro López  | pedro.lopez@pragma.com.co | Soledad |
| Alejandro Luna Miranda | alejandro.luna@pragma.com.co | Ibagué |
| Sebastian Medina Ochoa | sebastian.medina@pragma.com.co | Cali  |
| Cristian Turizo  | cristian.turizo@pragma.com.co | Medellin  |
| David Sanchez | david.sanchezm@pragma.com.co | Bogotá |
| Jose Arraut | jose.arrauttg@pragma.com.co | Medellin  |
| Claiderman Lozano  | alexander.lozano@pragma.co | Medellin |
| Johan Garrido  | johan.garrido@pragma.com.co | Bogotá |
| Juan Frasser | juan.frasser@pragma.com.co | Ibagué |
| Mauro Herrera | mauro.herrera@pragma.com.co | Panamá |
| Sofia Orozco  | sofia.orozco@pragma.com.co | Bogotá |
| George Parra  | sebastian.parra@tablaito.com | Medellin  |
| Andres Martinez  | andres.martinezm@pragma.com.co | Soledad |
| Luis Briceño  | luis.briceno@pragma.com.co | Cali |
| Christian Torres | christian.torres@pragma.com.co | Perú |
| Stick Cruz Madera | stick.cruz@pragma.com.co | Medellin  |
