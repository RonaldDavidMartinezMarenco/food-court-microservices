# Plaza de comidas — qué es el proyecto

Este documento resume el reto a partir de [food-court-guide.md](food-court-guide.md) y del arquetipo en `docs/architecture/pelicula-hexagonal`. No agrega reglas de negocio que el brief no tenga.

## Qué se construye

El backend de una plazoleta de comidas. Varios restaurantes publican su menú. Una persona identificada como cliente pide platos de un solo restaurante a la vez. El sistema reemplaza un backend viejo. El reto no incluye pago ni un frontend obligatorio.

## Quién usa el sistema

| Rol | Qué puede hacer |
| --- | --- |
| Administrador | Crear restaurantes y la cuenta del propietario de cada uno. |
| Propietario | Crear platos, cambiar precio y descripción, y activarlos o desactivarlos. Crear cuentas de empleados. Ver la duración de cada pedido y el ranking de empleados. |
| Empleado | Ver pedidos pendientes de su restaurante, asignárselos, marcarlos listos y entregarlos. |
| Cliente | Ver restaurantes y sus platos, hacer un pedido, cancelarlo si sigue pendiente y ver cuánto tiempo pasó en cada estado. |

## Cómo avanza un pedido

1. El cliente confirma el pedido. Queda en `PENDING` y entra a la lista de pendientes de ese restaurante.
2. Un empleado de ese restaurante se lo asigna y pasa a `IN_PREPARATION`.
3. Mientras sigue `PENDING`, el cliente puede cancelarlo (`CANCELLED`). Después de ese estado ya no.
4. El empleado termina la preparación, el pedido pasa a `READY` y el cliente recibe un PIN por mensaje.
5. El empleado recibe el PIN y marca el pedido `DELIVERED`.

Un pedido solo contiene platos de un mismo restaurante. Si el cliente ya tiene un pedido en `PENDING`, `IN_PREPARATION` o `READY`, no puede abrir otro hasta que ese termine en `DELIVERED` o `CANCELLED`.

En código y en la API los estados van en inglés. El brief los nombra en español: pendiente, en preparación, listo, entregado y cancelado.

## Cómo debe construirse

El brief exige esto:

- Cada microservicio es un repositorio Git aparte.
- Cada uno arranca del arquetipo compartido y usa arquitectura hexagonal.
- Cada uno documenta su API con OpenAPI.
- Cada historia de usuario va en su propia rama y lleva pruebas unitarias.
- Se trabaja una historia a la vez.
- La base relacional puede ser MySQL o PostgreSQL. En este proyecto la base es PostgreSQL.
- El PIN se envía por SMS con Twilio, desde `messaging-service`.
- PostgreSQL guarda usuarios, la plazoleta y la trazabilidad. MongoDB y DynamoDB no entran en esta versión.

El arquetipo es Spring Boot 4.1.1, Java 21 y Maven, con el árbol hexagonal vacío (`domain`, `application`, `infrastructure`). H2 se reemplaza por PostgreSQL. El detalle y las 18 historias están en `.cursor/plans/food-court-architecture-setup.md`.

## Servicios

El repositorio maestro es `food-court-microservices`. Los cuatro servicios viven como carpetas dentro de ese directorio, cada uno con su propio repositorio Git. El `.gitignore` del maestro los excluye, así que no entran en su historial:

| Nombre del reto | Repositorio | Qué hace |
| --- | --- | --- |
| Usuarios | `user-service` | Cuentas, roles y login. |
| Plazoleta | `plaza-service` | Restaurantes, platos y pedidos. |
| Trazabilidad | `traceability-service` | Historial de estados y eficiencia. |
| Mensajería | `messaging-service` | SMS del PIN con Twilio. |

Las historias están en [Cronograma reto plazoleta.xlsx](Cronograma%20reto%20plazoleta.xlsx), hoja `BACKLOG`, semanas 1 a 3, de la HU 1 a la HU 18.

Un cliente web con React, Next.js y TypeScript queda como stack opcional, en otro repositorio, y no forma parte de la entrega obligatoria del reto.
