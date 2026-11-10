# Seed data for manual testing

`scripts/seed.sh` loads a known set of accounts, restaurants, and dishes through the public API. Each row goes through the same validation, bcrypt hashing, and ownership checks as a manual call, so the seed only contains data the services accept.

The seed covers the stories implemented so far: HU 1 (owners), HU 2 (restaurants), HU 3 and HU 4 (dishes), HU 5 (login), HU 6 (employees), HU 8 (customers), HU 9 (the restaurant list), HU 10 (the menu of a restaurant), HU 11 (placing an order), HU 12 (the employee order list), HU 13 (an employee assigns a pending order), HU 14 (that employee marks it ready and the customer receives the PIN by SMS), HU 15 (that employee delivers it with the PIN), HU 16 (a customer cancels a pending order), and HU 17 (the customer reads the status history of that order). The manual cases also cover HU 7 (enable or disable a dish); the script itself leaves every dish active. La Parrilla de Carlos places twelve `PENDING` orders, then Pedro assigns Ronald's and leaves it in `IN_PREPARATION`. The script does not mark that order ready or delivered. Lucía cancels hers and places another, so the restaurant ends with one `IN_PREPARATION`, one `CANCELLED`, and eleven `PENDING`. Sushi Zen 88 has one `PENDING` order. Mateo has none, so a manual call can place his. Each status change the script performs is stored by traceability-service.

## Contents

- [Reset and load](#reset-and-load)
- [Accounts](#accounts)
- [Restaurants](#restaurants)
- [Dishes](#dishes)
- [Orders](#orders)
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
# start user-service, plaza-service, and traceability-service with ./mvnw spring-boot:run
bash scripts/seed.sh
```

The script waits up to two minutes for both services, needs `curl` and `jq`, and stops at the first unexpected HTTP status with the response body. When `carlos.ramirez@example.com` can already log in, it reports that the seed is loaded and changes nothing.

| Variable | Default |
| --- | --- |
| `USER_URL` | `http://localhost:8081` |
| `PLAZA_URL` | `http://localhost:8082` |
| `TRACEABILITY_URL` | `http://localhost:8083` |
| `SEED_PASSWORD` | `Password123` |
| `SEED_PIN` | none; required, six digits, same value as `APP_PIN_FIXED` on plaza-service |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | `BOOTSTRAP_ADMIN_EMAIL` and `BOOTSTRAP_ADMIN_PASSWORD` from `.env` |

`SEED_PIN` is the PIN of every order the running plaza-service marks ready. Compose passes it as `APP_PIN_FIXED`. Leave that variable empty and plaza keeps a random PIN; the script then stops before creating data, because it cannot read the PIN back from the API. Set it in `.env`, recreate plaza-service, and run the script. The SMS uses the same digits. The value is not a default in this document.

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
| 9 | `CUSTOMER` | Ronald Martínez | `ronald.martinez@example.com` | `3011590640` | `+573011590640` | |
| 10 | `CUSTOMER` | Mateo Vargas | `mateo.vargas@example.com` | `3020202020` | `+573003330002` | |
| 11 | `OWNER` | Mariana Ortiz | `mariana.ortiz@example.com` | `1050505050` | `+573001110005` | 4 to 23 |

Owner birth dates: Carlos `1985-04-12`, Laura `1990-09-30`, Andrés `1978-01-20`, Mariana `1988-03-08`. Employees and customers have no birth date. A customer belongs to no restaurant.

Each account has a purpose in the tests:

- Carlos owns two restaurants, so one owner can manage more than one menu and employee list.
- Laura owns one restaurant. She is the "other owner" for the 403 cases.
- Andrés is an owner without a restaurant. He can receive a new restaurant (HU 2) and is rejected when he creates employees or dishes.
- La Parrilla de Carlos, Sushi Zen 88, and Pizzería Bella Napoli each have at least one employee for the order stories.
- Ronald and Mateo are customers. Ronald's order at La Parrilla de Carlos starts as `PENDING` and stays in `IN_PREPARATION` with Pedro. The script does not mark it ready, so no PIN is sent for that order. Mateo has no order and can place one. Ronald is also the caller for the restaurant list and for each restaurant menu. Eleven more customers each hold one `PENDING` order at La Parrilla, and Sara holds one at Sushi Zen, so the employee list can be paged and kept inside one restaurant. Lucía later cancels her first order and places another.
- Mariana owns the twenty restaurants added for pagination. Café Andino has the twelve dishes used to page a menu. She has no employees. The other nineteen restaurants of hers have no dishes.

## Restaurants

Created by the administrator.

| Id | Name | NIT | Address | Phone | Owner | Alphabetical |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | La Parrilla de Carlos | `900100001` | Calle 10 # 5-20, Local 101 | `+576015550101` | 2 Carlos | 13 |
| 2 | Sushi Zen 88 | `900100002` | Carrera 7 # 45-12, Local 102 | `+576015550102` | 2 Carlos | 21 |
| 3 | Pizzería Bella Napoli | `900100003` | Avenida 68 # 22-30, Local 201 | `+576015550103` | 3 Laura | 19 |
| 4 | Zumos Tropicales | `900200001` | Calle 50 # 10-01, Local 301 | `+576015550201` | 11 Mariana | 23 |
| 5 | Café Andino | `900200002` | Calle 50 # 10-02, Local 302 | `+576015550202` | 11 Mariana | 5 |
| 6 | Ñapa Antioqueña | `900200003` | Calle 50 # 10-03, Local 303 | `+576015550203` | 11 Mariana | 17 |
| 7 | Burger & Co. | `900200004` | Calle 50 # 10-04, Local 304 | `+576015550204` | 11 Mariana | 4 |
| 8 | 7 Mares Cevichería | `900200005` | Calle 50 # 10-05, Local 305 | `+576015550205` | 11 Mariana | 1 |
| 9 | Oishi Ramen | `900200006` | Calle 50 # 10-06, Local 306 | `+576015550206` | 11 Mariana | 18 |
| 10 | empanadas la 33 | `900200007` | Calle 50 # 10-07, Local 307 | `+576015550207` | 11 Mariana | 8 |
| 11 | Kebab Estambul | `900200008` | Calle 50 # 10-08, Local 308 | `+576015550208` | 11 Mariana | 12 |
| 12 | Ánfora Mediterránea | `900200009` | Calle 50 # 10-09, Local 309 | `+576015550209` | 11 Mariana | 2 |
| 13 | Wok Express | `900200010` | Calle 50 # 10-10, Local 310 | `+576015550210` | 11 Mariana | 22 |
| 14 | Green Bowl | `900200011` | Calle 50 # 10-11, Local 311 | `+576015550211` | 11 Mariana | 10 |
| 15 | Nono Pasta Fresca | `900200012` | Calle 50 # 10-12, Local 312 | `+576015550212` | 11 Mariana | 16 |
| 16 | El Fogón Paisa | `900200013` | Calle 50 # 10-13, Local 313 | `+576015550213` | 11 Mariana | 7 |
| 17 | Dragón Dorado | `900200014` | Calle 50 # 10-14, Local 314 | `+576015550214` | 11 Mariana | 6 |
| 18 | Mama's Kitchen | `900200015` | Calle 50 # 10-15, Local 315 | `+576015550215` | 11 Mariana | 15 |
| 19 | Pollo Dorado 24-7 | `900200016` | Calle 50 # 10-16, Local 316 | `+576015550216` | 11 Mariana | 20 |
| 20 | Falafel King | `900200017` | Calle 50 # 10-17, Local 317 | `+576015550217` | 11 Mariana | 9 |
| 21 | La Taquería Mexicana | `900200018` | Calle 50 # 10-18, Local 318 | `+576015550218` | 11 Mariana | 14 |
| 22 | Hamburguesas El Corral | `900200019` | Calle 50 # 10-19, Local 319 | `+576015550219` | 11 Mariana | 11 |
| 23 | Arepas Doña Rosa | `900200020` | Calle 50 # 10-20, Local 320 | `+576015550220` | 11 Mariana | 3 |

Logos follow `https://images.example.com/logos/<slug>.png`. "Sushi Zen 88" has digits and a letter, which HU 2 allows. Restaurants 4 to 23 are created in an order that is not alphabetical, so a response ordered by id is visibly different from `GET /restaurants`. The names cover an initial accent, `Ñ`, a lowercase initial, a leading digit, `&`, `'`, `-`, and `.`. The alphabetical column is the Spanish order (`Ñ` after `N`, case ignored).

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

Dish 1 goes through HU 4 during the seed: created at 42000, then updated to 45000 with the description "Corte de res de 400 g a la parrilla con papas criollas y chimichurri." Each of these three restaurants has two or more categories. "Bebidas" is also on Café Andino, so a category filter stays inside the restaurant of the path.

Café Andino (id 5) has twelve more dishes, created by Mariana in an order that is not alphabetical. Names are ASCII so the page order does not depend on Spanish collation. The menu sorts by name, then by id.

| Id | Name | Category | Price | Alphabetical |
| --- | --- | --- | --- | --- |
| 12 | Mocha | Cafes | 6000 | 10 |
| 13 | Brownie | Pasteleria | 8000 | 2 |
| 14 | Americano | Cafes | 5000 | 1 |
| 15 | Cheesecake | Pasteleria | 11000 | 4 |
| 16 | Espresso | Cafes | 4000 | 5 |
| 17 | Galleta | Pasteleria | 3000 | 6 |
| 18 | Latte | Cafes | 7000 | 8 |
| 19 | Muffin | Pasteleria | 6500 | 11 |
| 20 | Capuccino | Cafes | 7500 | 3 |
| 21 | Waffle | Pasteleria | 9000 | 12 |
| 22 | Jugo de naranja | Bebidas | 7000 | 7 |
| 23 | Limonada de panela | Bebidas | 6500 | 9 |

All twenty-three dishes are active. A default page of Café Andino returns the first ten names and leaves Muffin and Waffle on the second page.

## Orders

Customers place orders through `POST /orders` after the menus exist. Mateo does not. The customer id comes from the token. Every stored order starts as `PENDING`, with no assigned employee and no PIN. A second call from the same customer is rejected while that order is still in progress. `POST /orders` cannot write a later status. After the list checks, Pedro assigns Ronald's order and the script leaves it in `IN_PREPARATION`. Lucía cancels order 2 and places order 14.

| Id | Customer | Restaurant | Status | Lines |
| --- | --- | --- | --- | --- |
| 1 | 9 Ronald Martínez | 1 La Parrilla de Carlos | `IN_PREPARATION`, employee 5 Pedro | Churrasco (1) quantity 1, Limonada de coco (4) quantity 2 |
| 2 | 12 Lucía Navarro | 1 | `CANCELLED` | Churrasco quantity 2 |
| 3 | 13 Diego Castaño | 1 | `PENDING` | Costillas BBQ quantity 1 |
| 4 | 14 Elena Ruiz | 1 | `PENDING` | Ensalada de la casa quantity 2 |
| 5 | 15 Hugo Peña | 1 | `PENDING` | Limonada de coco quantity 1 |
| 6 | 16 Irene Solís | 1 | `PENDING` | Churrasco quantity 1, Costillas BBQ quantity 1 |
| 7 | 17 Julián Mora | 1 | `PENDING` | Ensalada de la casa quantity 1, Limonada de coco quantity 2 |
| 8 | 18 Karla Díaz | 1 | `PENDING` | Churrasco quantity 2, Ensalada de la casa quantity 1 |
| 9 | 19 Nicolás Gil | 1 | `PENDING` | Costillas BBQ quantity 2, Limonada de coco quantity 1 |
| 10 | 20 Olga Pardo | 1 | `PENDING` | Churrasco quantity 1, Limonada de coco quantity 1 |
| 11 | 21 Pablo Ríos | 1 | `PENDING` | Costillas BBQ quantity 1, Ensalada de la casa quantity 2 |
| 12 | 22 Rosa Méndez | 1 | `PENDING` | Ensalada de la casa quantity 1, Limonada de coco quantity 1 |
| 13 | 23 Sara Kim | 2 Sushi Zen 88 | `PENDING` | Roll California (5) quantity 1 |
| 14 | 12 Lucía Navarro | 1 | `PENDING` | Churrasco quantity 2 |

The extra customers use password `Password123`. Documents run from `3030303003` to `3030303014`, phones from `+573003330003` to `+573003330014`, and emails are `lucia.navarro@example.com`, `diego.castano@example.com`, `elena.ruiz@example.com`, `hugo.pena@example.com`, `irene.solis@example.com`, `julian.mora@example.com`, `karla.diaz@example.com`, `nicolas.gil@example.com`, `olga.pardo@example.com`, `pablo.rios@example.com`, `rosa.mendez@example.com`, and `sara.kim@example.com`.

Pedro and Sofía both belong to restaurant 1. Before Pedro assigns order 1, both see twelve `PENDING` orders and an empty `IN_PREPARATION` page. After that assignment they see eleven `PENDING` orders and Ronald's order in `IN_PREPARATION`. Kenji sees only order 13. Valentina sees none. A page of 10 of the pending list leaves order 12 alone on the second page. The script stops there for Ronald's order. Lucía cancels order 2 and places order 14, so a finished seed has order 1 `IN_PREPARATION`, order 2 `CANCELLED`, and eleven `PENDING` orders at La Parrilla (3 through 12, and 14). The ready and delivered pages are empty. A page of 10 leaves order 14 alone on the second page.

`IN_PREPARATION` and `READY` also block a new order. This endpoint cannot create them; the use case tests cover those statuses. Ronald cannot place another order while order 1 stays in `IN_PREPARATION`. `CANCELLED` does not block, which is why Lucía can place order 14. A database that already lets Carlos log in is left unchanged. Load these orders with a fresh volume.

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
| Existing account | Administrator, `GET /users/2` | 200 with `id`, `role`, and `restaurantId` null |
| Employee account | Pedro, `GET /users/5` | 200 with `role` `EMPLOYEE` and `restaurantId` 1 |
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
| Document in use | `3011590640` | 409 |
| Role other than customer | `roleId` 1 | 400 "The role must be CUSTOMER" |
| Extra field | `"restaurantId": 5` | 400 |
| Role id as text or a decimal | `"roleId": "4"` or `4.5` | 400 |
| Phone shorter than 7 | `"+12345"` | 400 |
| Password of 40 `ñ` | 80 bytes, past the 72 bcrypt stores | 400 "The password must not exceed 72 bytes" |
| Then log in | `POST /login` with the new customer | 200 with `role: CUSTOMER` |

Example body:

```json
{
  "firstName": "Ronald",
  "lastName": "Martínez",
  "identityDocument": "3011590640",
  "phone": "+573011590640",
  "email": "ronald.martinez@example.com",
  "password": "Password123",
  "roleId": 4
}
```

### List restaurants (HU 9), `GET /restaurants`

A customer calls it. `page` starts at 0 and defaults to 0. `size` defaults to 10 and cannot exceed 50. The order is the name, using Spanish collation, then the id. A `sort` parameter is ignored. Each item has `id`, `name`, and `logoUrl`.

| Case | Caller and query | Expected |
| --- | --- | --- |
| First page | Ronald, no query | 200, 10 items, `totalItems` 23, `totalPages` 3, first name `7 Mares Cevichería` |
| Second page | Ronald, `page=1&size=10` | 200, `Nono Pasta Fresca` before `Ñapa Antioqueña` |
| Last page | Ronald, `page=2&size=10` | 200, three items: `Sushi Zen 88`, `Wok Express`, `Zumos Tropicales` |
| Page past the end | Ronald, `page=3&size=10` | 200 with `items: []` and the same totals |
| Whole catalog | Ronald, `size=50` | 200 with 23 items |
| Size above 50 | Ronald, `size=51` | 400 |
| Size zero | Ronald, `size=0` | 400 |
| Negative page | Ronald, `page=-1` | 400 |
| Page that is not an integer | Ronald, `page=abc` | 400 |
| Offset past the integer range | Ronald, `page=2147483647` | 400 |
| Sort parameter | Ronald, `sort=nit,desc` | 200, same order as the first page |
| Owner, administrator, or employee | Carlos, the administrator, or Pedro | 403 |
| No token | no `Authorization` header | 401 |

### List dishes (HU 10), `GET /restaurants/{restaurantId}/dishes`

A customer calls it. `page` starts at 0 and defaults to 0. `size` defaults to 10 and cannot exceed 50. `category` is optional. When it is present, surrounding spaces are removed and repeated spaces become one, then the value matches the stored category without regard to capitals. Each returned category keeps the capitals stored on the dish. The order is the dish name, then the id. A `sort` parameter is ignored. Inactive dishes are omitted from `items` and from the totals. Each item has `id`, `restaurantId`, `name`, `price`, `description`, `imageUrl`, and `category`.

| Case | Caller and query | Expected |
| --- | --- | --- |
| Whole small menu | Ronald, `/restaurants/1/dishes` | 200, four items, `totalItems` 4, `totalPages` 1 |
| Category of that restaurant | Ronald, `/restaurants/1/dishes?category=Carnes` | 200, Churrasco then Costillas BBQ |
| Same word, other restaurant | Ronald, `/restaurants/1/dishes?category=Bebidas` | 200, only Limonada de coco |
| Other case | Ronald, `/restaurants/1/dishes?category=carnes` | 200, Churrasco then Costillas BBQ, and each `category` is still `Carnes` |
| Surrounding spaces | Ronald, `/restaurants/1/dishes?category=%20%20Carnes%20%20` | 200, the two Carnes dishes |
| First page of a long menu | Ronald, `/restaurants/5/dishes` | 200, 10 items, `totalItems` 12, `totalPages` 2, first name `Americano` |
| Second page | Ronald, `/restaurants/5/dishes?page=1&size=10` | 200, Muffin then Waffle |
| Category on that menu | Ronald, `/restaurants/5/dishes?category=Bebidas` | 200, Jugo de naranja then Limonada de panela |
| Restaurant without dishes | Ronald, `/restaurants/4/dishes` | 200 with `items: []`, `totalItems` 0, `totalPages` 0 |
| Page past the end | Ronald, `/restaurants/1/dishes?page=1&size=10` | 200 with `items: []` and `totalItems` 4 |
| Category that is not on the menu | Ronald, `/restaurants/1/dishes?category=Pizzas` | 200 with `items: []` |
| Size above 50 | Ronald, `/restaurants/1/dishes?size=51` | 400 |
| Size zero | Ronald, `/restaurants/1/dishes?size=0` | 400 |
| Negative page | Ronald, `/restaurants/1/dishes?page=-1` | 400 |
| Page that is not an integer | Ronald, `/restaurants/1/dishes?page=abc` | 400 |
| Offset past the integer range | Ronald, `/restaurants/1/dishes?page=2147483647` | 400 |
| Empty category | Ronald, `/restaurants/1/dishes?category=` | 400 |
| Digits only | Ronald, `/restaurants/1/dishes?category=123` | 400 |
| Category longer than 50 | Ronald, `/restaurants/1/dishes?category=` followed by 51 `a` | 400 |
| Sort parameter | Ronald, `/restaurants/1/dishes?sort=price,desc` | 200, same order as the whole small menu |
| Id that is not positive | Ronald, `/restaurants/0/dishes` | 400 |
| Unknown restaurant | Ronald, `/restaurants/999/dishes` | 404 |
| Disabled dish | Carlos disables `/dishes/2`, then Ronald lists `/restaurants/1/dishes` | 200, three items, Costillas BBQ absent, `totalItems` 3 |
| Owner, administrator, or employee | Carlos, the administrator, or Pedro | 403 |
| No token | no `Authorization` header | 401 |

### Place an order (HU 11), `POST /orders`

A customer calls it. The customer id comes from the token. The body is the restaurant and the lines (`dishId`, `quantity`). `status`, `customerId`, `assignedEmployeeId`, and `pin` are rejected. The stored order is `PENDING`. `assignedEmployeeId` is null. The response has no `pinHash`. `Location` is `/orders/{id}`.

Ronald already has order 1, so she cannot place another. Mateo can. Quantity is a whole number from 1 to 50, and an order has from 1 to 20 lines. The same dish cannot appear twice.

| Case | Caller and body | Expected |
| --- | --- | --- |
| First order | Mateo, restaurant 1, Churrasco quantity 1 and Limonada de coco quantity 2 | 201, `status` `PENDING`, `assignedEmployeeId` null, no `pinHash`, `Location: /orders/{id}` |
| Second order while `PENDING` | Ronald, the same body as his seeded order | 409 "The customer already has an order in progress" |
| Dish of another restaurant | Mateo, restaurant 1 and Pizza Margarita (dish 8) | 409 "The dish does not belong to this restaurant" |
| Inactive dish | Carlos disables dish 2, then Mateo orders it at restaurant 1 | 409 "This dish is not available" |
| Unknown dish | Mateo, `dishId` 999 | 404 |
| Unknown restaurant | Mateo, `restaurantId` 999 | 404 |
| Empty lines | Mateo, `"lines": []` | 400 |
| Quantity zero, 51, or 1.5 | Mateo | 400 |
| Repeated dish | Mateo, Churrasco twice | 400 |
| Extra field | Mateo, `"status": "DELIVERED"` or `"customerId": 10` | 400 |
| More than 20 lines | Mateo | 400 |
| Owner, administrator, or employee | Carlos, the administrator, or Pedro | 403 |
| No token | no `Authorization` header | 401 |
| user-service stopped | Mateo, after user-service is down | 503 |

`IN_PREPARATION` and `READY` are not creatable here. The use case rejects them when the repository reports an order in either status. The seed leaves Ronald in `IN_PREPARATION`, so he cannot place another order. `CANCELLED` does not block; the seed places Lucía's second order after she cancels the first.

Example body, the one the seed stores for Ronald:

```json
{
  "restaurantId": 1,
  "lines": [
    { "dishId": 1, "quantity": 1 },
    { "dishId": 4, "quantity": 2 }
  ]
}
```

Placing Mateo's order at La Parrilla adds a thirteenth `PENDING` order there and changes the totals below. Run the list checks on a fresh seed first.

### List orders by status (HU 12), `GET /orders`

An employee calls it. `status` is required and must be exactly one of `PENDING`, `IN_PREPARATION`, `READY`, `DELIVERED`, or `CANCELLED`. `page` starts at 0 and defaults to 0. `size` defaults to 10 and cannot exceed 50. The restaurant is the one on the employee account. A `sort` parameter and a `restaurantId` parameter are ignored. The order is the id. Each item has `id`, `customerId`, `restaurantId`, `status`, `assignedEmployeeId`, and `lines`. `pinHash` is absent. An empty page is 200 with `totalPages` 0.

The rows below are the queues after Pedro has taken Ronald's order. The script leaves that order in `IN_PREPARATION`. A finished seed has also moved order 2 to `CANCELLED` and Lucía has placed order 14, so La Parrilla then has 11 `PENDING` orders (ids 3 through 12, and 14). Page 2 of size 10 holds order 14. `READY` and `DELIVERED` are empty, `IN_PREPARATION` contains order 1, and `CANCELLED` contains order 2. Kenji still sees only order 13.

| Case | Caller and query | Expected |
| --- | --- | --- |
| First page | Pedro, `status=PENDING&page=0&size=10` | 200, 10 items, `totalItems` 11, `totalPages` 2, first id 3, all restaurant 1 and `PENDING`, orders 1 and 2 absent |
| Second page | Pedro, `status=PENDING&page=1&size=10` | 200, one item, order 14 |
| Same restaurant, other employee | Sofía, `status=PENDING&page=0&size=10` | 200, same total and same first id as Pedro |
| Other restaurant | Kenji, `status=PENDING` | 200, one item, restaurant 2, not order 1 |
| Restaurant with no orders | Valentina, `status=PENDING` | 200, `totalItems` 0, `totalPages` 0 |
| Preparation | Pedro, `status=IN_PREPARATION` | 200, one item, order 1, `assignedEmployeeId` 5, restaurant 1. Sofía sees the same item |
| Ready or delivered | Pedro, `status=READY` or `DELIVERED` | 200, empty page |
| Cancelled | Pedro, `status=CANCELLED` | 200, one item, order 2 |
| Page past the end | Pedro, `status=PENDING&page=2&size=10` | 200 with `items: []` and `totalItems` 11 |
| Missing status | Pedro, no query | 400 |
| Unknown or Spanish status | Pedro, `status=PENDIENTE` or `status=pending` | 400 |
| Two statuses | Pedro, `status=PENDING&status=READY` | 400 |
| Size above 50, size zero, or negative page | Pedro | 400 |
| Sort or restaurant parameter | Pedro, `status=PENDING&sort=id,desc&restaurantId=2` | 200, still restaurant 1, still id order |
| Customer, owner, or administrator | Ronald, Carlos, or the administrator | 403, even when the status is invalid |
| No token | no `Authorization` header | 401 |

### Assign an order (HU 13), `POST /orders/{orderId}/assignment`

An employee calls it. There is no body. The employee id comes from the token and the restaurant comes from the employee account. The order must be `PENDING` and unassigned. The response is the same order with `status` `IN_PREPARATION` and `assignedEmployeeId` set. `pinHash` is absent. A second call is 409: the transition is not repeated as a success.

The seed assigns order 1 to Pedro and leaves it in `IN_PREPARATION`. After the script finishes, a second assignment is rejected because the order is `IN_PREPARATION`. Order 2 is `CANCELLED`; assigning it is rejected by the same rule.

| Case | Caller and path | Expected |
| --- | --- | --- |
| Take Ronald's order | Pedro, `POST /orders/1/assignment`, run before the seed's own assignment, or against a database where that order is still `PENDING` | 200, `status` `IN_PREPARATION`, `assignedEmployeeId` 5, same lines, no `pinHash` |
| After the seed | Pedro, `POST /orders/1/assignment` | 409 "The order is IN_PREPARATION and cannot be assigned" |
| Other employee of the same restaurant | Sofía, `POST /orders/1/assignment` | 409, same detail |
| Other restaurant | Kenji or Valentina, `POST /orders/1/assignment` | 404 "No order exists for this id" |
| Unknown id | Pedro, `POST /orders/999/assignment` | 404 |
| Id zero or text | Pedro, `/orders/0/assignment` or `/orders/abc/assignment` | 400 |
| Customer, owner, or administrator | Ronald, Carlos, or the administrator | 403 |
| No token | no `Authorization` header | 401 |
| Customer still blocked | Ronald, `POST /orders` with his original body | 409 "The customer already has an order in progress" |

Example response, Ronald's order after Pedro takes it:

```json
{
  "id": 1,
  "customerId": 9,
  "restaurantId": 1,
  "status": "IN_PREPARATION",
  "assignedEmployeeId": 5,
  "lines": [
    { "dishId": 1, "quantity": 1 },
    { "dishId": 4, "quantity": 2 }
  ]
}
```

### Mark an order ready (HU 14), `POST /orders/{orderId}/ready`

An employee calls it. There is no body. The employee must be the one assigned to the order, and the order must be `IN_PREPARATION`. The response is the same order with `status` `READY`. `pin` and `pinHash` are absent. The PIN goes out by SMS to the customer's phone. A second call is 409 and does not send another PIN. If the SMS is rejected, the order stays `IN_PREPARATION`.

The SMS goes out through textbee and the registered Android phone. The body is `Tu pedido #{id} de {restaurant} está listo.` and, on the next line, `Pin de seguridad: {pin}`. It arrives on an iPhone or an Android because it is a carrier SMS. The phone needs internet. It does not need to share a Wi-Fi network with these services. Without `TEXTBEE_API_KEY`, or if the phone is offline, the call returns 502 and the order stays `IN_PREPARATION`. `MESSAGING_PROVIDER=twilio` keeps the Twilio adapter available. A Twilio trial account still rejects this custom body.

After the seed, order 1 is still `IN_PREPARATION` and assigned to Pedro, so the success call below is the one the running database accepts.

| Case | Caller and path | Expected |
| --- | --- | --- |
| Mark Ronald's order | Pedro, `POST /orders/1/ready`, while it is still `IN_PREPARATION` | 200, `status` `READY`, `assignedEmployeeId` 5, same lines, no `pin`, no `pinHash` |
| After the seed | Pedro, `POST /orders/1/ready` | 200, `status` `READY`, `assignedEmployeeId` 5, same lines, no `pin`, no `pinHash`. This sends the SMS and moves the seeded order out of `IN_PREPARATION` |
| Other employee of the same restaurant | Sofía, `POST /orders/1/ready` | 409 "The order is assigned to another employee" while it is `IN_PREPARATION`, or 409 with the stored status after the seed |
| Other restaurant | Kenji or Valentina, `POST /orders/1/ready` | 404 "No order exists for this id" |
| Customer, owner, or administrator | Ronald, Carlos, or the administrator | 403 |
| No token | no `Authorization` header | 401 |
| Customer still blocked | Ronald, `POST /orders` with his original body | 409 "The customer already has an order in progress" |

Example response, Ronald's order after Pedro marks it ready:

```json
{
  "id": 1,
  "customerId": 9,
  "restaurantId": 1,
  "status": "READY",
  "assignedEmployeeId": 5,
  "lines": [
    { "dishId": 1, "quantity": 1 },
    { "dishId": 4, "quantity": 2 }
  ]
}
```

### Deliver an order (HU 15), `POST /orders/{orderId}/delivery`

An employee calls it. The body is `{"pin":"<six digits>"}`. The PIN is a JSON string so a leading zero is kept. The employee must be the one assigned to the order, and the order must be `READY`. The response is the same order with `status` `DELIVERED`. `pin` and `pinHash` are absent. The hash stays in the database. A second call is 409: `DELIVERED` does not change, including back to `READY`. A PIN that does not match does not write. There is no attempt limit and no SMS on this call.

The script does not deliver order 1. After the seed that order is `IN_PREPARATION`, so delivery is rejected until Pedro marks it ready and the customer has the PIN.

| Case | Caller and path | Expected |
| --- | --- | --- |
| Deliver Ronald's order | Pedro, `POST /orders/1/delivery` with `{"pin":"<SEED_PIN>"}`, while it is still `READY` | 200, `status` `DELIVERED`, `assignedEmployeeId` 5, same lines, no `pin`, no `pinHash` |
| After the seed | Pedro, `POST /orders/1/delivery` with any PIN | 409 "The order is IN_PREPARATION and cannot be delivered" |
| Wrong PIN | Pedro, `{"pin":"000000"}` while the order is `READY` and `SEED_PIN` is not `000000` | 409 "The security PIN does not match", order stays `READY` |
| Other employee, correct PIN | Sofía, `{"pin":"<SEED_PIN>"}` while the order is `READY` | 409 "The order is assigned to another employee", order stays `READY` |
| Other restaurant | Kenji or Valentina, `POST /orders/1/delivery` | 404 "No order exists for this id" |
| Unknown id | Pedro, `POST /orders/999/delivery` | 404 |
| Id zero or text | Pedro, `/orders/0/delivery` or `/orders/abc/delivery` | 400 |
| Missing body, short PIN, or extra field | Pedro, empty body, `{"pin":"12"}`, or `{"pin":"<SEED_PIN>","status":"CANCELLED"}` | 400, handler not reached |
| Customer, owner, or administrator | Ronald, Carlos, or the administrator | 403 |
| No token | no `Authorization` header | 401 |
| Assignment after delivery | Pedro, `POST /orders/1/assignment` | 409 "The order is DELIVERED and cannot be assigned" |
| Ready after delivery | Pedro, `POST /orders/1/ready` | 409 "The order is DELIVERED and cannot be marked ready" |
| Customer can order again | Ronald, `POST /orders` with his original body, after delivery and before order 14 exists | 201, `status` `PENDING` |
| Customer blocked again | Ronald, same body after order 14 exists | 409 "The customer already has an order in progress" |

Example request. `482913` is illustrative. The seed uses `SEED_PIN`, not this value.

```json
{
  "pin": "482913"
}
```

Example response, Ronald's order after Pedro delivers it:

```json
{
  "id": 1,
  "customerId": 9,
  "restaurantId": 1,
  "status": "DELIVERED",
  "assignedEmployeeId": 5,
  "lines": [
    { "dishId": 1, "quantity": 1 },
    { "dishId": 4, "quantity": 2 }
  ]
}
```

### Cancel an order (HU 16), `POST /orders/{orderId}/cancellation`

A customer calls it. There is no body. The customer id comes from the token. The order must belong to that customer and be `PENDING`. The response is the same order with `status` `CANCELLED`. Lines stay. `assignedEmployeeId` stays null on a pending order. `pin` and `pinHash` are absent. A second call is 409. The detail is exactly `Lo sentimos, tu pedido ya está en preparación y no puede cancelarse` for every status other than `PENDING`, including `IN_PREPARATION`, `READY`, `DELIVERED`, and `CANCELLED`.

After the seed, order 2 is already `CANCELLED` and Lucía's new order is 15, so her call on order 2 is the 409 and another `POST /orders` from her is 409 again. Run the success call before the script's own cancellation, while order 2 is still `PENDING`.

| Case | Caller and path | Expected |
| --- | --- | --- |
| Cancel Lucía's order | Lucía, `POST /orders/2/cancellation`, while it is still `PENDING` | 200, `status` `CANCELLED`, `customerId` 12, `restaurantId` 1, `assignedEmployeeId` null, Churrasco quantity 2, no `pin`, no `pinHash` |
| After the seed | Lucía, `POST /orders/2/cancellation` | 409 "Lo sentimos, tu pedido ya está en preparación y no puede cancelarse" |
| Order in preparation | Ronald, `POST /orders/1/cancellation` | 409, the same sentence, order stays `IN_PREPARATION` |
| Another customer's order | Ronald or Diego, `POST /orders/2/cancellation` | 404 "No order exists for this id" |
| Unknown id | Lucía, `POST /orders/999/cancellation` | 404 |
| Id zero or text | Lucía, `/orders/0/cancellation` or `/orders/abc/cancellation` | 400 |
| Employee, owner, or administrator | Pedro, Sofía, Carlos, or the administrator | 403 |
| No token | no `Authorization` header | 401 |
| Customer can order again | Lucía, `POST /orders` with restaurant 1 and Churrasco quantity 2, after cancellation and before order 15 exists | 201, `status` `PENDING` |
| Customer blocked again | Lucía, same body after order 15 exists | 409 "The customer already has an order in progress" |

Example response, Lucía's order after she cancels it:

```json
{
  "id": 2,
  "customerId": 12,
  "restaurantId": 1,
  "status": "CANCELLED",
  "assignedEmployeeId": null,
  "lines": [
    { "dishId": 1, "quantity": 2 }
  ]
}
```

### Read an order trace (HU 17), `GET /orders/{orderId}/trace`

This call belongs to traceability-service, on port 8083. A customer reads only an order that has status rows stored for that customer. The history is oldest first. `secondsInStatus` is the number of seconds until the next change. The current status leaves it null. The response has no employee id.

Plaza writes one row on each status change. After the seed, Ronald's order has `PENDING` and then `IN_PREPARATION`. The second row has `secondsInStatus` null. Lucía's cancelled order has `PENDING` and `CANCELLED`. A missing trace and another customer's order both answer 404.

| Case | Caller and path | Expected |
| --- | --- | --- |
| Ronald's order | Ronald, `GET http://localhost:8083/orders/1/trace` | 200, `PENDING` then `IN_PREPARATION`, last `secondsInStatus` null |
| Another customer | Mateo, `GET http://localhost:8083/orders/1/trace` | 404 "No trace exists for this order" |
| Employee, owner, or administrator | Pedro, Carlos, or the administrator | 403 |
| No token | no `Authorization` header | 401 |
| Id zero | Ronald, `GET http://localhost:8083/orders/0/trace` | 400 |

