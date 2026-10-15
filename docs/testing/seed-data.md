# Seed data for manual testing

`scripts/seed.sh` loads a known set of accounts, restaurants, and dishes through the public API. Each row goes through the same validation, bcrypt hashing, and ownership checks as a manual call, so the seed only contains data the services accept.

The seed covers the stories implemented so far: HU 1 (owners), HU 2 (restaurants), HU 3 and HU 4 (dishes), HU 5 (login), HU 6 (employees), and HU 8 (customers). The manual cases also cover HU 7 (enable or disable a dish); the script itself leaves every dish active. Orders do not exist yet; extend the script when HU 11 adds its endpoint.

## Contents

- [Reset and load](#reset-and-load)
- [Accounts](#accounts)
- [Restaurants](#restaurants)
- [Dishes](#dishes)
- [Get a token](#get-a-token)
- [Manual test cases](#manual-test-cases)

## Reset and load

The administrator is not part of the seed. `user-service` creates it on startup from the `BOOTSTRAP_ADMIN_*` values in `.env`, and the script logs in with those values.

Full stack in Compose:

```bash
docker compose down -v                          # deletes the Postgres volume
docker compose --env-file .env up -d --build
bash scripts/seed.sh
```

Postgres in Compose and the services from Maven:

```bash
docker compose --env-file .env -f compose.postgres.yml down -v
docker compose --env-file .env -f compose.postgres.yml up -d --wait
# start user-service and plaza-service with ./mvnw spring-boot:run
bash scripts/seed.sh
```

The script waits up to two minutes for both services, needs `curl` and `jq`, and stops at the first unexpected HTTP status with the response body. When `carlos.ramirez@example.com` can already log in, it reports that the seed is loaded and changes nothing.

| Variable | Default |
| --- | --- |
| `USER_URL` | `http://localhost:8081` |
| `PLAZA_URL` | `http://localhost:8082` |
| `SEED_PASSWORD` | `Password123` |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | `BOOTSTRAP_ADMIN_EMAIL` and `BOOTSTRAP_ADMIN_PASSWORD` from `.env` |

The ids below are the ones an empty database assigns. The script prints the ids it received at the end.

## Accounts

Every seeded account uses the password `Password123`. The administrator uses the password in `.env` (`secret12` in `.env.example`).

| Id | Role | Name | Email | Identity document | Phone | Restaurant |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `ADMINISTRATOR` | from `.env` | `admin@example.com` | from `.env` | from `.env` | |
| 2 | `OWNER` | Carlos Ramírez | `carlos.ramirez@example.com` | `1010101010` | `+573001110001` | 1 and 2 |
| 3 | `OWNER` | Laura Gómez | `laura.gomez@example.com` | `1020202020` | `+573001110002` | 3 |
| 4 | `OWNER` | Andrés Torres | `andres.torres@example.com` | `1030303030` | `+573001110003` | none |
| 5 | `EMPLOYEE` | Pedro Martínez | `pedro.martinez@example.com` | `2010101010` | `+573002220001` | 1 |
| 6 | `EMPLOYEE` | Sofía Herrera | `sofia.herrera@example.com` | `2020202020` | `+573002220002` | 1 |
| 7 | `EMPLOYEE` | Kenji Morales | `kenji.morales@example.com` | `2030303030` | `+573002220003` | 2 |
| 8 | `EMPLOYEE` | Valentina Rossi | `valentina.rossi@example.com` | `2040404040` | `+573002220004` | 3 |
| 9 | `CUSTOMER` | Camila Restrepo | `camila.restrepo@example.com` | `3010101010` | `+573003330001` | |
| 10 | `CUSTOMER` | Mateo Vargas | `mateo.vargas@example.com` | `3020202020` | `+573003330002` | |

Owner birth dates: Carlos `1985-04-12`, Laura `1990-09-30`, Andrés `1978-01-20`. Employees and customers have no birth date. A customer belongs to no restaurant.

Each account has a purpose in the tests:

- Carlos owns two restaurants, so one owner can manage more than one menu and employee list.
- Laura owns one restaurant. She is the "other owner" for the 403 cases.
- Andrés is an owner without a restaurant. He can receive a new restaurant (HU 2) and is rejected when he creates employees or dishes.
- Each restaurant has at least one employee for the order stories.
- Camila and Mateo are customers. HU 11 can give one of them an order in progress and leave the other free to order.

## Restaurants

Created by the administrator.

| Id | Name | NIT | Address | Phone | Owner |
| --- | --- | --- | --- | --- | --- |
| 1 | La Parrilla de Carlos | `900100001` | Calle 10 # 5-20, Local 101 | `+576015550101` | 2 Carlos |
| 2 | Sushi Zen 88 | `900100002` | Carrera 7 # 45-12, Local 102 | `+576015550102` | 2 Carlos |
| 3 | Pizzería Bella Napoli | `900100003` | Avenida 68 # 22-30, Local 201 | `+576015550103` | 3 Laura |

Logos follow `https://images.example.com/logos/<slug>.png`. "Sushi Zen 88" has digits and a letter, which HU 2 allows.

## Dishes

Created by the owner of each restaurant. All are active. Images follow `https://images.example.com/dishes/<slug>.jpg`.

| Id | Restaurant | Name | Category | Price |
| --- | --- | --- | --- | --- |
| 1 | 1 La Parrilla de Carlos | Churrasco | Carnes | 45000 |
| 2 | 1 La Parrilla de Carlos | Costillas BBQ | Carnes | 38000 |
| 3 | 1 La Parrilla de Carlos | Ensalada de la casa | Entradas | 15000 |
| 4 | 1 La Parrilla de Carlos | Limonada de coco | Bebidas | 9000 |
| 5 | 2 Sushi Zen 88 | Roll California | Rolls | 28000 |
| 6 | 2 Sushi Zen 88 | Nigiri de salmón | Nigiris | 24000 |
| 7 | 2 Sushi Zen 88 | Té verde | Bebidas | 7000 |
| 8 | 3 Pizzería Bella Napoli | Pizza Margarita | Pizzas | 32000 |
| 9 | 3 Pizzería Bella Napoli | Pizza Pepperoni | Pizzas | 35000 |
| 10 | 3 Pizzería Bella Napoli | Lasaña boloñesa | Pastas | 30000 |
| 11 | 3 Pizzería Bella Napoli | Tiramisú | Postres | 14000 |

Dish 1 goes through HU 4 during the seed: created at 42000, then updated to 45000 with the description "Corte de res de 400 g a la parrilla con papas criollas y chimichurri." Each restaurant has two or more categories, and "Bebidas" exists in two restaurants, for the category filter in HU 10.

## Get a token

```bash
TOKEN=$(curl -s -X POST http://localhost:8081/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"carlos.ramirez@example.com","password":"Password123"}' | jq -r .accessToken)

curl -s http://localhost:8082/restaurants/1 -H "Authorization: Bearer $TOKEN"
```

Swagger UI: [user-service](http://localhost:8081/swagger-ui.html) and [plaza-service](http://localhost:8082/swagger-ui.html). Use **Authorize** with the `accessToken` from `/login`.

## Manual test cases

These statuses were checked against a freshly seeded database. A rejected case changes nothing. A 201 or a 200 on `PUT` adds or changes a row, so reset and seed again to return to the tables above.

### Login (HU 5)

| Case | Call | Expected |
| --- | --- | --- |
| Valid credentials | `POST /login` as any account above | 200 with `accessToken`, `userId`, `role` |
| Wrong password | `POST /login` Carlos with `Wrong12345` | 401 |
| Malformed email | `POST /login` with `"email": "carlos"` | 400 |
| No token on a protected route | `GET /users/2` without `Authorization` | 401 |

### Accounts (`GET /users/{id}`)

| Case | Caller | Expected |
| --- | --- | --- |
| Existing account | Administrator, `GET /users/2` | 200 with `id` and `role` |
| Id that is not positive | `GET /users/0` | 400 |
| Unknown id | `GET /users/999` | 404 |

### Create owner (HU 1), `POST /owners`

| Case | Caller and body | Expected |
| --- | --- | --- |
| New owner | Administrator, new email and document, adult birth date | 201 |
| Email in use | `carlos.ramirez@example.com` | 409 |
| Document in use | `1010101010` | 409 |
| Minor | `birthDate` `2015-01-01` | 400 "The owner must be an adult" |
| Phone of 14 characters | `+5730011100071` | 400 |
| Document with a letter | `10A0707070` | 400 |
| Caller is not an administrator | Carlos | 403 |

### Create restaurant (HU 2), `POST /restaurants`

| Case | Caller and body | Expected |
| --- | --- | --- |
| New restaurant for an owner | Administrator, `ownerId` 4 (Andrés) | 201 |
| `ownerId` of an employee | `ownerId` 5 (Pedro) | 403 "The account must have the owner role" |
| Unknown `ownerId` | `ownerId` 999 | 404 |
| Name in use, other case | `la parrilla de carlos` | 409 |
| NIT in use | `900100001` | 409 |
| Name of digits only | `12345` | 400 |
| Caller is not an administrator | Carlos | 403 |

### Restaurant owner lookup, `GET /restaurants/{id}`

| Case | Caller | Expected |
| --- | --- | --- |
| Owner reads | Carlos, `/restaurants/1` | 200 with `id` and `ownerId` |
| Employee reads | Pedro | 403 |
| Id that is not positive | `/restaurants/0` | 400 |
| Unknown id | `/restaurants/999` | 404 |

### Create dish (HU 3), `POST /dishes`

| Case | Caller and body | Expected |
| --- | --- | --- |
| Own restaurant | Carlos, `restaurantId` 1 | 201 with `active: true` |
| Restaurant of another owner | Carlos, `restaurantId` 3 | 403 |
| Restaurant of another owner | Laura, `restaurantId` 1 | 403 |
| Employee or administrator | Pedro or the administrator | 403 |
| Price 0 | `"price": 0` | 400 |
| Decimal price | `"price": 100.5` | 400 |
| Unknown restaurant | `restaurantId` 999 | 404 |

### Update dish (HU 4), `PUT /dishes/{id}`

The body accepts only `price` and `description`.

| Case | Caller and body | Expected |
| --- | --- | --- |
| Own dish | Carlos, `/dishes/2` | 200 |
| Dish of another owner | Laura, `/dishes/1` | 403 |
| Extra field | Carlos, body with `"name"` | 400 |
| Id that is not positive | `/dishes/0` | 400 |
| Unknown dish | `/dishes/999` | 404 |

### Enable or disable a dish (HU 7), `PUT /dishes/{id}/active`

The body is `{"active": true}` or `{"active": false}`. Sending the same state again returns 200.

| Case | Caller and body | Expected |
| --- | --- | --- |
| Disable own dish | Carlos, `/dishes/2`, `"active": false` | 200 with `active: false` |
| Enable own dish | Carlos, `/dishes/2`, `"active": true` | 200 with `active: true` |
| Same state again | Carlos, `/dishes/2`, `"active": false` twice | 200 both times |
| Dish of another owner | Laura, `/dishes/1` | 403 |
| Employee or administrator | Pedro or the administrator | 403 |
| Extra field | Carlos, body with `"price"` | 400 |
| Active as text or a number | `"active": "false"`, `0`, or `1` | 400 |
| Missing active | `{}` | 400 |
| Id that is not positive | `/dishes/0` | 400 |
| Unknown dish | `/dishes/999` | 404 |

### Create employee (HU 6), `POST /employees`

`roleId` must be `3` (`EMPLOYEE`).

| Case | Caller and body | Expected |
| --- | --- | --- |
| Own restaurant | Carlos, `restaurantId` 2 | 201 with `role: EMPLOYEE` and `restaurantId` |
| Restaurant of another owner | Carlos, `restaurantId` 3 | 403 |
| Restaurant of another owner | Laura, `restaurantId` 1 | 403 |
| Owner without that restaurant | Andrés, `restaurantId` 1 | 403 |
| Administrator or employee | The administrator or Pedro | 403 |
| Role other than employee | Carlos, `roleId` 2 | 400 "The role must be EMPLOYEE" |
| Unknown restaurant | Carlos, `restaurantId` 999 | 404 |
| Email in use | `pedro.martinez@example.com` | 409 |
| Document in use | `2010101010` | 409 |

Example body:

```json
{
  "firstName": "Juan",
  "lastName": "Pérez",
  "identityDocument": "2050505050",
  "phone": "+573009990000",
  "email": "juan.perez@example.com",
  "password": "Password123",
  "roleId": 3,
  "restaurantId": 2
}
```

### Create customer (HU 8), `POST /customers`

The call needs no access token. `roleId` must be `4` (`CUSTOMER`). The body accepts no restaurant and no birth date.

| Case | Body | Expected |
| --- | --- | --- |
| New customer | New email and document, `roleId` 4, no token | 201 with `role: CUSTOMER` and `Location: /users/{id}` |
| Same customer again | The email just registered | 409 |
| Document in use | `3010101010` | 409 |
| Role other than customer | `roleId` 1 | 400 "The role must be CUSTOMER" |
| Extra field | `"restaurantId": 5` | 400 |
| Role id as text or a decimal | `"roleId": "4"` or `4.5` | 400 |
| Phone shorter than 7 | `"+12345"` | 400 |
| Password of 40 `ñ` | 80 bytes, past the 72 bcrypt stores | 400 "The password must not exceed 72 bytes" |
| Then log in | `POST /login` with the new customer | 200 with `role: CUSTOMER` |

Example body:

```json
{
  "firstName": "Camila",
  "lastName": "Restrepo",
  "identityDocument": "3010101010",
  "phone": "+573003330001",
  "email": "camila.restrepo@example.com",
  "password": "Password123",
  "roleId": 4
}
```
