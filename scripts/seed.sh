#!/usr/bin/env bash
# Load demo data for manual testing through the public API.
# Every row passes the same validation, bcrypt, and ownership checks as a manual call.
# Run it once on an empty database: user-service creates the bootstrap administrator on startup,
# and this script logs in as that administrator. The accounts are listed in docs/testing/seed-data.md.
#
# Requires curl and jq. The services must be running:
#   docker compose --env-file .env up -d --build
#   bash scripts/seed.sh

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

user_url="${USER_URL:-http://localhost:8081}"
plaza_url="${PLAZA_URL:-http://localhost:8082}"
trace_url="${TRACEABILITY_URL:-http://localhost:8083}"
seed_password="${SEED_PASSWORD:-Password123}"
employee_role_id=3
customer_role_id=4

env_value() {
  local file="$root/.env"
  [[ -f $file ]] || return 0
  grep -E "^$1=" "$file" | tail -n 1 | cut -d= -f2- | sed -E 's/[[:space:]]+#.*$//; s/^"(.*)"$/\1/'
}

admin_email="${ADMIN_EMAIL:-$(env_value BOOTSTRAP_ADMIN_EMAIL)}"
admin_password="${ADMIN_PASSWORD:-$(env_value BOOTSTRAP_ADMIN_PASSWORD)}"

if [[ -z $admin_email || -z $admin_password ]]; then
  echo "Set BOOTSTRAP_ADMIN_EMAIL and BOOTSTRAP_ADMIN_PASSWORD in .env, or ADMIN_EMAIL and ADMIN_PASSWORD." >&2
  exit 1
fi

seed_pin="${SEED_PIN:-$(env_value SEED_PIN)}"
if [[ ! $seed_pin =~ ^[0-9]{6}$ ]]; then
  echo "Set SEED_PIN to 6 digits in the environment or in .env, and start plaza-service with APP_PIN_FIXED set to the same value." >&2
  exit 1
fi
wrong_pin=000000
if [[ $seed_pin == 000000 ]]; then
  wrong_pin=111111
fi

for tool in curl jq; do
  command -v "$tool" > /dev/null || { echo "$tool is required." >&2; exit 1; }
done

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT

# Prints the HTTP status and leaves the body in $body_file.
send() {
  local method=$1 url=$2 token=$3 body=$4
  local args=(-sS -o "$body_file" -w '%{http_code}' -X "$method" "$url")
  [[ -n $token ]] && args+=(-H "Authorization: Bearer $token")
  [[ -n $body ]] && args+=(-H 'Content-Type: application/json' --data "$body")
  curl "${args[@]}"
}

# Prints the response body. Stops the script when the status is not the expected one.
call() {
  local method=$1 url=$2 token=$3 body=$4 expected=$5
  local status
  status="$(send "$method" "$url" "$token" "$body")"
  if [[ $status != "$expected" ]]; then
    echo "$method $url returned $status, expected $expected:" >&2
    cat "$body_file" >&2
    echo >&2
    exit 1
  fi
  cat "$body_file"
}

wait_for() {
  local name=$1 url=$2
  for _ in $(seq 1 60); do
    if curl -fsS -o /dev/null "$url/v3/api-docs" 2> /dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "$name did not answer at $url within 120 seconds." >&2
  exit 1
}

credentials() {
  jq -n --arg email "$1" --arg password "$2" '{email: $email, password: $password}'
}

login() {
  call POST "$user_url/login" "" "$(credentials "$1" "$2")" 200 | jq -r .accessToken
}

create_owner() {
  local body
  body="$(jq -n \
    --arg firstName "$1" --arg lastName "$2" --arg identityDocument "$3" \
    --arg phone "$4" --arg birthDate "$5" --arg email "$6" --arg password "$seed_password" \
    '{firstName: $firstName, lastName: $lastName, identityDocument: $identityDocument,
      phone: $phone, birthDate: $birthDate, email: $email, password: $password}')"
  call POST "$user_url/owners" "$admin_token" "$body" 201 | jq -r .id
}

create_restaurant() {
  local body
  body="$(jq -n \
    --arg name "$1" --arg nit "$2" --arg address "$3" --arg phone "$4" \
    --arg logoUrl "$5" --argjson ownerId "$6" \
    '{name: $name, nit: $nit, address: $address, phone: $phone, logoUrl: $logoUrl, ownerId: $ownerId}')"
  call POST "$plaza_url/restaurants" "$admin_token" "$body" 201 | jq -r .id
}

create_dish() {
  local token=$1 body
  body="$(jq -n \
    --arg name "$2" --argjson price "$3" --arg description "$4" \
    --arg imageUrl "$5" --arg category "$6" --argjson restaurantId "$7" \
    '{name: $name, price: $price, description: $description, imageUrl: $imageUrl,
      category: $category, restaurantId: $restaurantId}')"
  call POST "$plaza_url/dishes" "$token" "$body" 201 | jq -r .id
}

update_dish() {
  local token=$1 id=$2 body
  body="$(jq -n --argjson price "$3" --arg description "$4" '{price: $price, description: $description}')"
  call PUT "$plaza_url/dishes/$id" "$token" "$body" 200 > /dev/null
}

create_employee() {
  local token=$1 body
  body="$(jq -n \
    --arg firstName "$2" --arg lastName "$3" --arg identityDocument "$4" \
    --arg phone "$5" --arg email "$6" --arg password "$seed_password" \
    --argjson roleId "$employee_role_id" --argjson restaurantId "$7" \
    '{firstName: $firstName, lastName: $lastName, identityDocument: $identityDocument,
      phone: $phone, email: $email, password: $password, roleId: $roleId, restaurantId: $restaurantId}')"
  call POST "$user_url/employees" "$token" "$body" 201 | jq -r .id
}

create_customer() {
  local body
  body="$(jq -n \
    --arg firstName "$1" --arg lastName "$2" --arg identityDocument "$3" \
    --arg phone "$4" --arg email "$5" --arg password "$seed_password" \
    --argjson roleId "$customer_role_id" \
    '{firstName: $firstName, lastName: $lastName, identityDocument: $identityDocument,
      phone: $phone, email: $email, password: $password, roleId: $roleId}')"
  call POST "$user_url/customers" "" "$body" 201 | jq -r .id
}

order_at() {
  local restaurant=$1 email=$2 lines=$3 token body
  token="$(login "$email" "$seed_password")"
  body="$(jq -n --argjson restaurantId "$restaurant" --argjson lines "$lines" \
    '{restaurantId: $restaurantId, lines: $lines}')"
  call POST "$plaza_url/orders" "$token" "$body" 201 | jq -r .id
}

wait_for user-service "$user_url"
wait_for plaza-service "$plaza_url"

if [[ "$(send POST "$user_url/login" "" "$(credentials carlos.ramirez@example.com "$seed_password")")" == 200 ]]; then
  echo "The seed is already loaded: carlos.ramirez@example.com can log in. Reset the database to load it again."
  exit 0
fi

wait_for traceability-service "$trace_url"

admin_login="$(call POST "$user_url/login" "" "$(credentials "$admin_email" "$admin_password")" 200)"
admin_token="$(jq -r .accessToken <<< "$admin_login")"
admin_id="$(jq -r .userId <<< "$admin_login")"

echo "Owners (HU 1)"
carlos_id="$(create_owner Carlos "Ramírez" 1010101010 +573001110001 1985-04-12 carlos.ramirez@example.com)"
laura_id="$(create_owner Laura "Gómez" 1020202020 +573001110002 1990-09-30 laura.gomez@example.com)"
andres_id="$(create_owner "Andrés" Torres 1030303030 +573001110003 1978-01-20 andres.torres@example.com)"

echo "Restaurants (HU 2)"
parrilla_id="$(create_restaurant "La Parrilla de Carlos" 900100001 "Calle 10 # 5-20, Local 101" +576015550101 \
  https://images.example.com/logos/la-parrilla.png "$carlos_id")"
sushi_id="$(create_restaurant "Sushi Zen 88" 900100002 "Carrera 7 # 45-12, Local 102" +576015550102 \
  https://images.example.com/logos/sushi-zen.png "$carlos_id")"
napoli_id="$(create_restaurant "Pizzería Bella Napoli" 900100003 "Avenida 68 # 22-30, Local 201" +576015550103 \
  https://images.example.com/logos/bella-napoli.png "$laura_id")"

carlos_token="$(login carlos.ramirez@example.com "$seed_password")"
laura_token="$(login laura.gomez@example.com "$seed_password")"

echo "Dishes (HU 3)"
churrasco_id="$(create_dish "$carlos_token" Churrasco 42000 \
  "Corte de res a la parrilla con papas criollas y chimichurri." \
  https://images.example.com/dishes/churrasco.jpg Carnes "$parrilla_id")"
costillas_id="$(create_dish "$carlos_token" "Costillas BBQ" 38000 \
  "Costillas de cerdo en salsa barbacoa con mazorca asada." \
  https://images.example.com/dishes/costillas-bbq.jpg Carnes "$parrilla_id")"
ensalada_id="$(create_dish "$carlos_token" "Ensalada de la casa" 15000 \
  "Lechuga, tomate, aguacate y queso campesino." \
  https://images.example.com/dishes/ensalada.jpg Entradas "$parrilla_id")"
limonada_id="$(create_dish "$carlos_token" "Limonada de coco" 9000 \
  "Limonada natural licuada con crema de coco." \
  https://images.example.com/dishes/limonada-coco.jpg Bebidas "$parrilla_id")"
california_id="$(create_dish "$carlos_token" "Roll California" 28000 \
  "Cangrejo, aguacate y pepino envueltos en arroz con ajonjolí." \
  https://images.example.com/dishes/roll-california.jpg Rolls "$sushi_id")"
nigiri_id="$(create_dish "$carlos_token" "Nigiri de salmón" 24000 \
  "Seis piezas de salmón fresco sobre arroz." \
  https://images.example.com/dishes/nigiri-salmon.jpg Nigiris "$sushi_id")"
te_id="$(create_dish "$carlos_token" "Té verde" 7000 \
  "Té verde japonés servido caliente." \
  https://images.example.com/dishes/te-verde.jpg Bebidas "$sushi_id")"
margarita_id="$(create_dish "$laura_token" "Pizza Margarita" 32000 \
  "Salsa de tomate, mozzarella y albahaca fresca." \
  https://images.example.com/dishes/pizza-margarita.jpg Pizzas "$napoli_id")"
pepperoni_id="$(create_dish "$laura_token" "Pizza Pepperoni" 35000 \
  "Mozzarella y pepperoni horneados en horno de leña." \
  https://images.example.com/dishes/pizza-pepperoni.jpg Pizzas "$napoli_id")"
lasana_id="$(create_dish "$laura_token" "Lasaña boloñesa" 30000 \
  "Capas de pasta con carne en salsa boloñesa y bechamel." \
  https://images.example.com/dishes/lasana.jpg Pastas "$napoli_id")"
tiramisu_id="$(create_dish "$laura_token" "Tiramisú" 14000 \
  "Postre italiano con café y mascarpone." \
  https://images.example.com/dishes/tiramisu.jpg Postres "$napoli_id")"

echo "Dish update (HU 4)"
update_dish "$carlos_token" "$churrasco_id" 45000 \
  "Corte de res de 400 g a la parrilla con papas criollas y chimichurri."

echo "Employees (HU 6)"
pedro_id="$(create_employee "$carlos_token" Pedro "Martínez" 2010101010 +573002220001 \
  pedro.martinez@example.com "$parrilla_id")"
sofia_id="$(create_employee "$carlos_token" "Sofía" Herrera 2020202020 +573002220002 \
  sofia.herrera@example.com "$parrilla_id")"
kenji_id="$(create_employee "$carlos_token" Kenji Morales 2030303030 +573002220003 \
  kenji.morales@example.com "$sushi_id")"
valentina_id="$(create_employee "$laura_token" Valentina Rossi 2040404040 +573002220004 \
  valentina.rossi@example.com "$napoli_id")"

echo "Customers (HU 8)"
ronald_id="$(create_customer Ronald "Martínez" 3011590640 +573011590640 ronald.martinez@example.com)"
mateo_id="$(create_customer Mateo Vargas 3020202020 +573003330002 mateo.vargas@example.com)"

echo "Restaurants for pagination (HU 9)"
mariana_id="$(create_owner Mariana Ortiz 1050505050 +573001110005 1988-03-08 mariana.ortiz@example.com)"
zumos_id=""
cafe_id=""
pagination_restaurants=(
  "Zumos Tropicales|zumos-tropicales"
  "Café Andino|cafe-andino"
  "Ñapa Antioqueña|napa-antioquena"
  "Burger & Co.|burger-co"
  "7 Mares Cevichería|7-mares"
  "Oishi Ramen|oishi-ramen"
  "empanadas la 33|empanadas-la-33"
  "Kebab Estambul|kebab-estambul"
  "Ánfora Mediterránea|anfora-mediterranea"
  "Wok Express|wok-express"
  "Green Bowl|green-bowl"
  "Nono Pasta Fresca|nono-pasta-fresca"
  "El Fogón Paisa|el-fogon-paisa"
  "Dragón Dorado|dragon-dorado"
  "Mama's Kitchen|mamas-kitchen"
  "Pollo Dorado 24-7|pollo-dorado"
  "Falafel King|falafel-king"
  "La Taquería Mexicana|la-taqueria-mexicana"
  "Hamburguesas El Corral|hamburguesas-el-corral"
  "Arepas Doña Rosa|arepas-dona-rosa"
)
n=1
for entry in "${pagination_restaurants[@]}"; do
  name="${entry%%|*}"
  slug="${entry#*|}"
  nn="$(printf '%02d' "$n")"
  restaurant_id="$(create_restaurant "$name" "9002000${nn}" "Calle 50 # 10-${nn}, Local 3${nn}" "+5760155502${nn}" \
    "https://images.example.com/logos/${slug}.png" "$mariana_id")"
  if [[ $slug == "zumos-tropicales" ]]; then
    zumos_id=$restaurant_id
  elif [[ $slug == "cafe-andino" ]]; then
    cafe_id=$restaurant_id
  fi
  n=$((n + 1))
done

echo "Dishes for pagination (HU 10)"
mariana_token="$(login mariana.ortiz@example.com "$seed_password")"
create_dish "$mariana_token" Mocha 6000 \
  "Cafe espresso con chocolate." \
  https://images.example.com/dishes/mocha.jpg Cafes "$cafe_id" > /dev/null
create_dish "$mariana_token" Brownie 8000 \
  "Brownie de chocolate con nueces." \
  https://images.example.com/dishes/brownie.jpg Pasteleria "$cafe_id" > /dev/null
create_dish "$mariana_token" Americano 5000 \
  "Cafe filtrado largo." \
  https://images.example.com/dishes/americano.jpg Cafes "$cafe_id" > /dev/null
create_dish "$mariana_token" Cheesecake 11000 \
  "Tarta de queso al horno." \
  https://images.example.com/dishes/cheesecake.jpg Pasteleria "$cafe_id" > /dev/null
create_dish "$mariana_token" Espresso 4000 \
  "Cafe corto y concentrado." \
  https://images.example.com/dishes/espresso.jpg Cafes "$cafe_id" > /dev/null
create_dish "$mariana_token" Galleta 3000 \
  "Galleta de avena y pasas." \
  https://images.example.com/dishes/galleta.jpg Pasteleria "$cafe_id" > /dev/null
create_dish "$mariana_token" Latte 7000 \
  "Cafe con leche vaporizada." \
  https://images.example.com/dishes/latte.jpg Cafes "$cafe_id" > /dev/null
create_dish "$mariana_token" Muffin 6500 \
  "Muffin de arandanos." \
  https://images.example.com/dishes/muffin.jpg Pasteleria "$cafe_id" > /dev/null
create_dish "$mariana_token" Capuccino 7500 \
  "Cafe con espuma de leche." \
  https://images.example.com/dishes/capuccino.jpg Cafes "$cafe_id" > /dev/null
create_dish "$mariana_token" Waffle 9000 \
  "Waffle con miel." \
  https://images.example.com/dishes/waffle.jpg Pasteleria "$cafe_id" > /dev/null
create_dish "$mariana_token" "Jugo de naranja" 7000 \
  "Jugo de naranja natural." \
  https://images.example.com/dishes/jugo-naranja.jpg Bebidas "$cafe_id" > /dev/null
create_dish "$mariana_token" "Limonada de panela" 6500 \
  "Limonada con panela." \
  https://images.example.com/dishes/limonada-panela.jpg Bebidas "$cafe_id" > /dev/null

for email in pedro.martinez@example.com sofia.herrera@example.com kenji.morales@example.com \
    valentina.rossi@example.com andres.torres@example.com \
    ronald.martinez@example.com mateo.vargas@example.com mariana.ortiz@example.com; do
  login "$email" "$seed_password" > /dev/null
done

echo "Restaurant list (HU 9)"
ronald_token="$(login ronald.martinez@example.com "$seed_password")"
restaurant_page="$(call GET "$plaza_url/restaurants?page=0&size=10" "$ronald_token" "" 200)"
total_items="$(jq -r .totalItems <<< "$restaurant_page")"
first_name="$(jq -r '.items[0].name' <<< "$restaurant_page")"
if [[ $total_items != 23 || $first_name != "7 Mares Cevichería" ]]; then
  echo "GET /restaurants returned totalItems=$total_items and first name '$first_name'." >&2
  exit 1
fi
echo "totalItems=$total_items"
jq -r '.items[].name' <<< "$restaurant_page"

echo "Dish list (HU 10)"
carnes="$(call GET "$plaza_url/restaurants/$parrilla_id/dishes?category=Carnes" "$ronald_token" "" 200)"
parrilla_bebidas="$(call GET "$plaza_url/restaurants/$parrilla_id/dishes?category=Bebidas" "$ronald_token" "" 200)"
lower_carnes="$(call GET "$plaza_url/restaurants/$parrilla_id/dishes?category=carnes" "$ronald_token" "" 200)"
cafe_first="$(call GET "$plaza_url/restaurants/$cafe_id/dishes?page=0&size=10" "$ronald_token" "" 200)"
cafe_second="$(call GET "$plaza_url/restaurants/$cafe_id/dishes?page=1&size=10" "$ronald_token" "" 200)"
cafe_bebidas="$(call GET "$plaza_url/restaurants/$cafe_id/dishes?category=Bebidas" "$ronald_token" "" 200)"
zumos_menu="$(call GET "$plaza_url/restaurants/$zumos_id/dishes" "$ronald_token" "" 200)"
if [[ $(jq -r .totalItems <<< "$carnes") != 2 \
    || $(jq -r .totalItems <<< "$parrilla_bebidas") != 1 \
    || $(jq -r '.items[0].name' <<< "$parrilla_bebidas") != "Limonada de coco" \
    || $(jq -r .totalItems <<< "$lower_carnes") != 2 \
    || $(jq -r '.items[0].name' <<< "$lower_carnes") != "Churrasco" \
    || $(jq -r '.items[1].name' <<< "$lower_carnes") != "Costillas BBQ" \
    || $(jq -r '.items[0].category' <<< "$lower_carnes") != "Carnes" \
    || $(jq -r .totalItems <<< "$cafe_first") != 12 \
    || $(jq -r .totalPages <<< "$cafe_first") != 2 \
    || $(jq -r '.items | length' <<< "$cafe_first") != 10 \
    || $(jq -r '.items[0].name' <<< "$cafe_first") != "Americano" \
    || $(jq -r '.items | length' <<< "$cafe_second") != 2 \
    || $(jq -r '.items[0].name' <<< "$cafe_second") != "Muffin" \
    || $(jq -r '.items[1].name' <<< "$cafe_second") != "Waffle" \
    || $(jq -r .totalItems <<< "$cafe_bebidas") != 2 \
    || $(jq -r '.items[0].name' <<< "$cafe_bebidas") != "Jugo de naranja" \
    || $(jq -r '.items[1].name' <<< "$cafe_bebidas") != "Limonada de panela" \
    || $(jq -r .totalItems <<< "$zumos_menu") != 0 \
    || $(jq -r .totalPages <<< "$zumos_menu") != 0 ]]; then
  echo "GET /restaurants/{id}/dishes did not match the seeded menu." >&2
  exit 1
fi
echo "Cafe Andino totalItems=12"

echo "Order (HU 11)"
order_body="$(jq -n \
  --argjson restaurantId "$parrilla_id" \
  --argjson churrasco "$churrasco_id" \
  --argjson limonada "$limonada_id" \
  '{restaurantId: $restaurantId, lines: [
      {dishId: $churrasco, quantity: 1},
      {dishId: $limonada, quantity: 2}
    ]}')"
order="$(call POST "$plaza_url/orders" "$ronald_token" "$order_body" 201)"
order_id="$(jq -r .id <<< "$order")"
if [[ $(jq -r .status <<< "$order") != PENDING \
    || $(jq -r .restaurantId <<< "$order") != "$parrilla_id" \
    || $(jq -r .customerId <<< "$order") != "$ronald_id" \
    || $(jq -r .assignedEmployeeId <<< "$order") != "null" \
    || $(jq -r 'has("pinHash")' <<< "$order") != false \
    || $(jq -r '.lines | length' <<< "$order") != 2 \
    || $(jq -r '.lines[0].dishId' <<< "$order") != "$churrasco_id" \
    || $(jq -r '.lines[0].quantity' <<< "$order") != 1 \
    || $(jq -r '.lines[1].dishId' <<< "$order") != "$limonada_id" \
    || $(jq -r '.lines[1].quantity' <<< "$order") != 2 ]]; then
  echo "POST /orders did not store Ronald's order as PENDING." >&2
  echo "$order" >&2
  exit 1
fi
call POST "$plaza_url/orders" "$ronald_token" "$order_body" 409 > /dev/null
echo "Ronald order $order_id is PENDING. A second order was rejected."

echo "Orders for the employee list (HU 12)"
# Eleven more PENDING orders at La Parrilla, then one at Sushi Zen. Mateo stays without an order.
# Each customer can hold only one order in progress, so each row is a different account.
parrilla_orders=(
  "Lucía|Navarro|3030303003|+573003330003|lucia.navarro@example.com|$(jq -cn --argjson dish "$churrasco_id" '[{dishId:$dish,quantity:2}]')"
  "Diego|Castaño|3030303004|+573003330004|diego.castano@example.com|$(jq -cn --argjson dish "$costillas_id" '[{dishId:$dish,quantity:1}]')"
  "Elena|Ruiz|3030303005|+573003330005|elena.ruiz@example.com|$(jq -cn --argjson dish "$ensalada_id" '[{dishId:$dish,quantity:2}]')"
  "Hugo|Peña|3030303006|+573003330006|hugo.pena@example.com|$(jq -cn --argjson dish "$limonada_id" '[{dishId:$dish,quantity:1}]')"
  "Irene|Solís|3030303007|+573003330007|irene.solis@example.com|$(jq -cn --argjson a "$churrasco_id" --argjson b "$costillas_id" '[{dishId:$a,quantity:1},{dishId:$b,quantity:1}]')"
  "Julián|Mora|3030303008|+573003330008|julian.mora@example.com|$(jq -cn --argjson a "$ensalada_id" --argjson b "$limonada_id" '[{dishId:$a,quantity:1},{dishId:$b,quantity:2}]')"
  "Karla|Díaz|3030303009|+573003330009|karla.diaz@example.com|$(jq -cn --argjson a "$churrasco_id" --argjson b "$ensalada_id" '[{dishId:$a,quantity:2},{dishId:$b,quantity:1}]')"
  "Nicolás|Gil|3030303010|+573003330010|nicolas.gil@example.com|$(jq -cn --argjson a "$costillas_id" --argjson b "$limonada_id" '[{dishId:$a,quantity:2},{dishId:$b,quantity:1}]')"
  "Olga|Pardo|3030303011|+573003330011|olga.pardo@example.com|$(jq -cn --argjson a "$churrasco_id" --argjson b "$limonada_id" '[{dishId:$a,quantity:1},{dishId:$b,quantity:1}]')"
  "Pablo|Ríos|3030303012|+573003330012|pablo.rios@example.com|$(jq -cn --argjson a "$costillas_id" --argjson b "$ensalada_id" '[{dishId:$a,quantity:1},{dishId:$b,quantity:2}]')"
  "Rosa|Méndez|3030303013|+573003330013|rosa.mendez@example.com|$(jq -cn --argjson a "$ensalada_id" --argjson b "$limonada_id" '[{dishId:$a,quantity:1},{dishId:$b,quantity:1}]')"
)
lucia_id=""
lucia_order=""
for entry in "${parrilla_orders[@]}"; do
  IFS='|' read -r first last document phone email lines <<< "$entry"
  customer_id="$(create_customer "$first" "$last" "$document" "$phone" "$email")"
  created="$(order_at "$parrilla_id" "$email" "$lines")"
  if [[ $email == lucia.navarro@example.com ]]; then
    lucia_id="$customer_id"
    lucia_order="$created"
  fi
  echo "customer $customer_id ordered $created at La Parrilla"
done
sushi_customer="$(create_customer Sara Kim 3030303014 +573003330014 sara.kim@example.com)"
sushi_order="$(order_at "$sushi_id" sara.kim@example.com "$(jq -cn --argjson dish "$california_id" '[{dishId:$dish,quantity:1}]')")"
echo "customer $sushi_customer ordered $sushi_order at Sushi Zen"

pedro_token="$(login pedro.martinez@example.com "$seed_password")"
sofia_token="$(login sofia.herrera@example.com "$seed_password")"
kenji_token="$(login kenji.morales@example.com "$seed_password")"
valentina_token="$(login valentina.rossi@example.com "$seed_password")"
pending_page="$(call GET "$plaza_url/orders?status=PENDING&page=0&size=10" "$pedro_token" "" 200)"
pending_next="$(call GET "$plaza_url/orders?status=PENDING&page=1&size=10" "$pedro_token" "" 200)"
preparing="$(call GET "$plaza_url/orders?status=IN_PREPARATION" "$pedro_token" "" 200)"
sofia_page="$(call GET "$plaza_url/orders?status=PENDING&page=0&size=10" "$sofia_token" "" 200)"
kenji_page="$(call GET "$plaza_url/orders?status=PENDING" "$kenji_token" "" 200)"
valentina_page="$(call GET "$plaza_url/orders?status=PENDING" "$valentina_token" "" 200)"
if ! jq -e --argjson restaurant "$parrilla_id" --argjson first "$order_id" '
    .totalItems == 12 and .totalPages == 2 and (.items | length) == 10 and .items[0].id == $first
    and all(.items[]; .status == "PENDING" and .restaurantId == $restaurant and .assignedEmployeeId == null and (has("pinHash") | not))
  ' <<< "$pending_page" > /dev/null \
  || ! jq -e --argjson restaurant "$parrilla_id" '
    .totalItems == 12 and (.items | length) == 2
    and all(.items[]; .restaurantId == $restaurant and .status == "PENDING")
  ' <<< "$pending_next" > /dev/null \
  || ! jq -e '.totalItems == 0 and .totalPages == 0 and (.items | length) == 0' <<< "$preparing" > /dev/null \
  || [[ $(jq -r .totalItems <<< "$sofia_page") != 12 || $(jq -r '.items[0].id' <<< "$sofia_page") != "$order_id" ]] \
  || ! jq -e --argjson restaurant "$sushi_id" --argjson foreign "$order_id" '
    .totalItems == 1 and .items[0].restaurantId == $restaurant and .items[0].id != $foreign
  ' <<< "$kenji_page" > /dev/null \
  || ! jq -e '.totalItems == 0 and .totalPages == 0' <<< "$valentina_page" > /dev/null; then
  echo "GET /orders did not match the seeded restaurant queues." >&2
  echo "$pending_page" >&2
  exit 1
fi
call GET "$plaza_url/orders?status=PENDING" "$ronald_token" "" 403 > /dev/null
call GET "$plaza_url/orders?status=PENDING" "$carlos_token" "" 403 > /dev/null
call GET "$plaza_url/orders?status=PENDING" "$admin_token" "" 403 > /dev/null
call GET "$plaza_url/orders?status=PENDIENTE" "$pedro_token" "" 400 > /dev/null
call GET "$plaza_url/orders" "$pedro_token" "" 400 > /dev/null
echo "Pedro sees 12 PENDING orders at La Parrilla. Kenji sees the Sushi order. Valentina sees none."

echo "Assign order (HU 13)"
assigned="$(call POST "$plaza_url/orders/$order_id/assignment" "$pedro_token" "" 200)"
if [[ $(jq -r .status <<< "$assigned") != IN_PREPARATION \
    || $(jq -r .id <<< "$assigned") != "$order_id" \
    || $(jq -r .customerId <<< "$assigned") != "$ronald_id" \
    || $(jq -r .restaurantId <<< "$assigned") != "$parrilla_id" \
    || $(jq -r .assignedEmployeeId <<< "$assigned") != "$pedro_id" \
    || $(jq -r 'has("pinHash")' <<< "$assigned") != false \
    || $(jq -r '.lines | length' <<< "$assigned") != 2 \
    || $(jq -r '.lines[0].dishId' <<< "$assigned") != "$churrasco_id" \
    || $(jq -r '.lines[0].quantity' <<< "$assigned") != 1 \
    || $(jq -r '.lines[1].dishId' <<< "$assigned") != "$limonada_id" \
    || $(jq -r '.lines[1].quantity' <<< "$assigned") != 2 ]]; then
  echo "POST /orders/{id}/assignment did not move Ronald's order to IN_PREPARATION." >&2
  echo "$assigned" >&2
  exit 1
fi
pending_after="$(call GET "$plaza_url/orders?status=PENDING&page=0&size=10" "$pedro_token" "" 200)"
preparing_after="$(call GET "$plaza_url/orders?status=IN_PREPARATION" "$pedro_token" "" 200)"
sofia_preparing="$(call GET "$plaza_url/orders?status=IN_PREPARATION" "$sofia_token" "" 200)"
if ! jq -e --argjson restaurant "$parrilla_id" --argjson taken "$order_id" '
    .totalItems == 11 and .totalPages == 2 and (.items | length) == 10
    and all(.items[]; .status == "PENDING" and .restaurantId == $restaurant and .id != $taken and .assignedEmployeeId == null)
  ' <<< "$pending_after" > /dev/null \
  || ! jq -e --argjson restaurant "$parrilla_id" --argjson taken "$order_id" --argjson employee "$pedro_id" '
    .totalItems == 1 and (.items | length) == 1
    and .items[0].id == $taken and .items[0].status == "IN_PREPARATION"
    and .items[0].assignedEmployeeId == $employee and .items[0].restaurantId == $restaurant
    and (.items[0] | has("pinHash") | not)
  ' <<< "$preparing_after" > /dev/null \
  || ! jq -e --argjson taken "$order_id" --argjson employee "$pedro_id" '
    .totalItems == 1 and .items[0].id == $taken and .items[0].assignedEmployeeId == $employee
  ' <<< "$sofia_preparing" > /dev/null; then
  echo "The queues did not reflect Ronald's assignment." >&2
  echo "$pending_after" >&2
  echo "$preparing_after" >&2
  exit 1
fi
call POST "$plaza_url/orders/$order_id/assignment" "$sofia_token" "" 409 > /dev/null
call POST "$plaza_url/orders/$order_id/assignment" "$pedro_token" "" 409 > /dev/null
call POST "$plaza_url/orders/$order_id/assignment" "$kenji_token" "" 404 > /dev/null
call POST "$plaza_url/orders/$order_id/assignment" "$valentina_token" "" 404 > /dev/null
call POST "$plaza_url/orders/$order_id/assignment" "$ronald_token" "" 403 > /dev/null
call POST "$plaza_url/orders/$order_id/assignment" "$carlos_token" "" 403 > /dev/null
call POST "$plaza_url/orders/$order_id/assignment" "$admin_token" "" 403 > /dev/null
call POST "$plaza_url/orders/0/assignment" "$pedro_token" "" 400 > /dev/null
call POST "$plaza_url/orders/abc/assignment" "$pedro_token" "" 400 > /dev/null
call POST "$plaza_url/orders" "$ronald_token" "$order_body" 409 > /dev/null
echo "Pedro took Ronald's order. It stays IN_PREPARATION. La Parrilla has 11 PENDING orders left."

preparing_kept="$(call GET "$plaza_url/orders?status=IN_PREPARATION" "$pedro_token" "" 200)"
ready_empty="$(call GET "$plaza_url/orders?status=READY" "$pedro_token" "" 200)"
delivered_empty="$(call GET "$plaza_url/orders?status=DELIVERED" "$pedro_token" "" 200)"
if ! jq -e --argjson taken "$order_id" --argjson employee "$pedro_id" '
    .totalItems == 1 and .items[0].id == $taken and .items[0].status == "IN_PREPARATION"
    and .items[0].assignedEmployeeId == $employee
  ' <<< "$preparing_kept" > /dev/null \
  || ! jq -e '.totalItems == 0 and (.items | length) == 0' <<< "$ready_empty" > /dev/null \
  || ! jq -e '.totalItems == 0 and (.items | length) == 0' <<< "$delivered_empty" > /dev/null; then
  echo "Ronald's order did not stay IN_PREPARATION." >&2
  echo "$preparing_kept" >&2
  exit 1
fi

echo "Cancel order (HU 16)"
cannot_cancel="Lo sentimos, tu pedido ya está en preparación y no puede cancelarse"
if [[ -z ${lucia_order:-} || -z ${lucia_id:-} ]]; then
  echo "Lucía's order id was not captured." >&2
  exit 1
fi
lucia_token="$(login lucia.navarro@example.com "$seed_password")"
diego_token="$(login diego.castano@example.com "$seed_password")"
rejected="$(call POST "$plaza_url/orders/$order_id/cancellation" "$ronald_token" "" 409)"
if [[ $(jq -r .detail <<< "$rejected") != "$cannot_cancel" ]]; then
  echo "Cancelling an order in preparation did not use the required sentence." >&2
  echo "$rejected" >&2
  exit 1
fi
call POST "$plaza_url/orders/$lucia_order/cancellation" "$pedro_token" "" 403 > /dev/null
call POST "$plaza_url/orders/$lucia_order/cancellation" "$sofia_token" "" 403 > /dev/null
call POST "$plaza_url/orders/$lucia_order/cancellation" "$carlos_token" "" 403 > /dev/null
call POST "$plaza_url/orders/$lucia_order/cancellation" "$admin_token" "" 403 > /dev/null
call POST "$plaza_url/orders/$lucia_order/cancellation" "$ronald_token" "" 404 > /dev/null
cancelled="$(call POST "$plaza_url/orders/$lucia_order/cancellation" "$lucia_token" "" 200)"
if [[ $(jq -r .status <<< "$cancelled") != CANCELLED \
    || $(jq -r .id <<< "$cancelled") != "$lucia_order" \
    || $(jq -r .customerId <<< "$cancelled") != "$lucia_id" \
    || $(jq -r .restaurantId <<< "$cancelled") != "$parrilla_id" \
    || $(jq -r .assignedEmployeeId <<< "$cancelled") != "null" \
    || $(jq -r 'has("pin")' <<< "$cancelled") != false \
    || $(jq -r 'has("pinHash")' <<< "$cancelled") != false \
    || $(jq -r '.lines | length' <<< "$cancelled") != 1 \
    || $(jq -r '.lines[0].dishId' <<< "$cancelled") != "$churrasco_id" \
    || $(jq -r '.lines[0].quantity' <<< "$cancelled") != 2 ]]; then
  echo "POST /orders/{id}/cancellation did not cancel Lucía's order." >&2
  echo "$cancelled" >&2
  exit 1
fi
again="$(call POST "$plaza_url/orders/$lucia_order/cancellation" "$lucia_token" "" 409)"
if [[ $(jq -r .detail <<< "$again") != "$cannot_cancel" ]]; then
  echo "A second cancellation did not use the required sentence." >&2
  echo "$again" >&2
  exit 1
fi
call POST "$plaza_url/orders/$lucia_order/cancellation" "$diego_token" "" 404 > /dev/null
call POST "$plaza_url/orders/$lucia_order/cancellation" "" "" 401 > /dev/null
call POST "$plaza_url/orders/0/cancellation" "$lucia_token" "" 400 > /dev/null
call POST "$plaza_url/orders/abc/cancellation" "$lucia_token" "" 400 > /dev/null
call POST "$plaza_url/orders/999/cancellation" "$lucia_token" "" 404 > /dev/null
lucia_body="$(jq -n --argjson restaurantId "$parrilla_id" --argjson dish "$churrasco_id" \
  '{restaurantId: $restaurantId, lines: [{dishId: $dish, quantity: 2}]}')"
lucia_next="$(call POST "$plaza_url/orders" "$lucia_token" "$lucia_body" 201)"
lucia_next_id="$(jq -r .id <<< "$lucia_next")"
if [[ $(jq -r .status <<< "$lucia_next") != PENDING \
    || $(jq -r .customerId <<< "$lucia_next") != "$lucia_id" \
    || $(jq -r .restaurantId <<< "$lucia_next") != "$parrilla_id" \
    || $(jq -r .assignedEmployeeId <<< "$lucia_next") != "null" \
    || $(jq -r 'has("pinHash")' <<< "$lucia_next") != false \
    || $(jq -r '.lines | length' <<< "$lucia_next") != 1 \
    || $(jq -r '.lines[0].dishId' <<< "$lucia_next") != "$churrasco_id" \
    || $(jq -r '.lines[0].quantity' <<< "$lucia_next") != 2 ]]; then
  echo "Lucía could not place another order after cancelling." >&2
  echo "$lucia_next" >&2
  exit 1
fi
call POST "$plaza_url/orders" "$lucia_token" "$lucia_body" 409 > /dev/null
cancelled_page="$(call GET "$plaza_url/orders?status=CANCELLED" "$pedro_token" "" 200)"
delivered_still="$(call GET "$plaza_url/orders?status=DELIVERED" "$pedro_token" "" 200)"
preparing_clear="$(call GET "$plaza_url/orders?status=IN_PREPARATION" "$pedro_token" "" 200)"
ready_clear="$(call GET "$plaza_url/orders?status=READY" "$pedro_token" "" 200)"
pending_after_cancel="$(call GET "$plaza_url/orders?status=PENDING&page=0&size=10" "$pedro_token" "" 200)"
pending_after_last="$(call GET "$plaza_url/orders?status=PENDING&page=1&size=10" "$pedro_token" "" 200)"
if ! jq -e --argjson cancelled "$lucia_order" --argjson customer "$lucia_id" --argjson restaurant "$parrilla_id" '
    .totalItems == 1 and (.items | length) == 1
    and .items[0].id == $cancelled and .items[0].status == "CANCELLED"
    and .items[0].customerId == $customer and .items[0].restaurantId == $restaurant
    and .items[0].assignedEmployeeId == null
    and (.items[0] | has("pinHash") | not)
  ' <<< "$cancelled_page" > /dev/null \
  || ! jq -e '.totalItems == 0 and (.items | length) == 0' <<< "$delivered_still" > /dev/null \
  || ! jq -e --argjson taken "$order_id" --argjson employee "$pedro_id" '
    .totalItems == 1 and (.items | length) == 1
    and .items[0].id == $taken and .items[0].status == "IN_PREPARATION"
    and .items[0].assignedEmployeeId == $employee
  ' <<< "$preparing_clear" > /dev/null \
  || ! jq -e '.totalItems == 0 and (.items | length) == 0' <<< "$ready_clear" > /dev/null \
  || ! jq -e --argjson restaurant "$parrilla_id" --argjson cancelled "$lucia_order" --argjson taken "$order_id" '
    .totalItems == 11 and .totalPages == 2 and (.items | length) == 10
    and all(.items[]; .status == "PENDING" and .restaurantId == $restaurant
      and .id != $cancelled and .id != $taken)
  ' <<< "$pending_after_cancel" > /dev/null \
  || ! jq -e --argjson restaurant "$parrilla_id" --argjson next "$lucia_next_id" '
    .totalItems == 11 and (.items | length) == 1
    and .items[0].id == $next and .items[0].status == "PENDING"
    and .items[0].restaurantId == $restaurant
  ' <<< "$pending_after_last" > /dev/null; then
  echo "The queues did not reflect Lucía's cancellation." >&2
  echo "$cancelled_page" >&2
  echo "$pending_after_cancel" >&2
  echo "$pending_after_last" >&2
  exit 1
fi
echo "Lucía cancelled order $lucia_order and placed order $lucia_next_id."

echo "Order trace (HU 17)"
mateo_token="$(login mateo.vargas@example.com "$seed_password")"
ronald_trace="$(call GET "$trace_url/orders/$order_id/trace" "$ronald_token" "" 200)"
if ! jq -e --argjson order "$order_id" --argjson customer "$ronald_id" --argjson restaurant "$parrilla_id" '
    .orderId == $order and .customerId == $customer and .restaurantId == $restaurant
    and (.changes | length) == 2
    and .changes[0].previousStatus == null and .changes[0].newStatus == "PENDING"
    and .changes[1].previousStatus == "PENDING" and .changes[1].newStatus == "IN_PREPARATION"
    and .changes[1].secondsInStatus == null
    and (.changes[0].secondsInStatus | type) == "number"
    and (.changes[0] | has("employeeId") | not)
  ' <<< "$ronald_trace" > /dev/null; then
  echo "Ronald could not read the trace of his order in preparation." >&2
  echo "$ronald_trace" >&2
  exit 1
fi
call GET "$trace_url/orders/$order_id/trace" "$mateo_token" "" 404 > /dev/null
call GET "$trace_url/orders/$order_id/trace" "$pedro_token" "" 403 > /dev/null
call GET "$trace_url/orders/$order_id/trace" "" "" 401 > /dev/null
echo "Ronald can read the trace of order $order_id. Mateo and Pedro cannot."

echo
echo "Seed loaded. Every seeded account uses the password: $seed_password"
printf '%-28s %-14s %4s  %s\n' "Email" "Role" "Id" "Restaurant id"
printf '%-28s %-14s %4s  %s\n' \
  "$admin_email" ADMINISTRATOR "$admin_id" - \
  carlos.ramirez@example.com OWNER "$carlos_id" "$parrilla_id, $sushi_id" \
  laura.gomez@example.com OWNER "$laura_id" "$napoli_id" \
  andres.torres@example.com OWNER "$andres_id" - \
  pedro.martinez@example.com EMPLOYEE "$pedro_id" "$parrilla_id" \
  sofia.herrera@example.com EMPLOYEE "$sofia_id" "$parrilla_id" \
  kenji.morales@example.com EMPLOYEE "$kenji_id" "$sushi_id" \
  valentina.rossi@example.com EMPLOYEE "$valentina_id" "$napoli_id" \
  ronald.martinez@example.com CUSTOMER "$ronald_id" - \
  mateo.vargas@example.com CUSTOMER "$mateo_id" - \
  mariana.ortiz@example.com OWNER "$mariana_id" "20 restaurants; menu on $cafe_id"
echo
echo "Restaurants: $parrilla_id La Parrilla de Carlos, $sushi_id Sushi Zen 88, $napoli_id Pizzería Bella Napoli"
echo "Pagination catalog: 20 restaurants of Mariana ($mariana_id), created after those three"
echo "Empty menu: $zumos_id Zumos Tropicales. Paged menu: $cafe_id Café Andino, 12 dishes"
echo "Dishes of La Parrilla de Carlos: $churrasco_id $costillas_id $ensalada_id $limonada_id"
echo "Dishes of Sushi Zen 88: $california_id $nigiri_id $te_id"
echo "Dishes of Pizzería Bella Napoli: $margarita_id $pepperoni_id $lasana_id $tiramisu_id"
echo "Orders: Ronald $order_id is IN_PREPARATION with Pedro $pedro_id. Lucía $lucia_order is CANCELLED. Lucía $lucia_next_id is PENDING. La Parrilla has 11 PENDING, 1 IN_PREPARATION and 1 CANCELLED. Sushi Zen has 1 PENDING. Mateo has no order."
