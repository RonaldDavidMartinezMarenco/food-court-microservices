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

wait_for user-service "$user_url"
wait_for plaza-service "$plaza_url"

if [[ "$(send POST "$user_url/login" "" "$(credentials carlos.ramirez@example.com "$seed_password")")" == 200 ]]; then
  echo "The seed is already loaded: carlos.ramirez@example.com can log in. Reset the database to load it again."
  exit 0
fi

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
camila_id="$(create_customer Camila Restrepo 3010101010 +573003330001 camila.restrepo@example.com)"
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
    camila.restrepo@example.com mateo.vargas@example.com mariana.ortiz@example.com; do
  login "$email" "$seed_password" > /dev/null
done

echo "Restaurant list (HU 9)"
camila_token="$(login camila.restrepo@example.com "$seed_password")"
restaurant_page="$(call GET "$plaza_url/restaurants?page=0&size=10" "$camila_token" "" 200)"
total_items="$(jq -r .totalItems <<< "$restaurant_page")"
first_name="$(jq -r '.items[0].name' <<< "$restaurant_page")"
if [[ $total_items != 23 || $first_name != "7 Mares Cevichería" ]]; then
  echo "GET /restaurants returned totalItems=$total_items and first name '$first_name'." >&2
  exit 1
fi
echo "totalItems=$total_items"
jq -r '.items[].name' <<< "$restaurant_page"

echo "Dish list (HU 10)"
carnes="$(call GET "$plaza_url/restaurants/$parrilla_id/dishes?category=Carnes" "$camila_token" "" 200)"
parrilla_bebidas="$(call GET "$plaza_url/restaurants/$parrilla_id/dishes?category=Bebidas" "$camila_token" "" 200)"
lower_carnes="$(call GET "$plaza_url/restaurants/$parrilla_id/dishes?category=carnes" "$camila_token" "" 200)"
cafe_first="$(call GET "$plaza_url/restaurants/$cafe_id/dishes?page=0&size=10" "$camila_token" "" 200)"
cafe_second="$(call GET "$plaza_url/restaurants/$cafe_id/dishes?page=1&size=10" "$camila_token" "" 200)"
cafe_bebidas="$(call GET "$plaza_url/restaurants/$cafe_id/dishes?category=Bebidas" "$camila_token" "" 200)"
zumos_menu="$(call GET "$plaza_url/restaurants/$zumos_id/dishes" "$camila_token" "" 200)"
if [[ $(jq -r .totalItems <<< "$carnes") != 2 \
    || $(jq -r .totalItems <<< "$parrilla_bebidas") != 1 \
    || $(jq -r '.items[0].name' <<< "$parrilla_bebidas") != "Limonada de coco" \
    || $(jq -r .totalItems <<< "$lower_carnes") != 0 \
    || $(jq -r .totalPages <<< "$lower_carnes") != 0 \
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
  camila.restrepo@example.com CUSTOMER "$camila_id" - \
  mateo.vargas@example.com CUSTOMER "$mateo_id" - \
  mariana.ortiz@example.com OWNER "$mariana_id" "20 restaurants; menu on $cafe_id"
echo
echo "Restaurants: $parrilla_id La Parrilla de Carlos, $sushi_id Sushi Zen 88, $napoli_id Pizzería Bella Napoli"
echo "Pagination catalog: 20 restaurants of Mariana ($mariana_id), created after those three"
echo "Empty menu: $zumos_id Zumos Tropicales. Paged menu: $cafe_id Café Andino, 12 dishes"
echo "Dishes of La Parrilla de Carlos: $churrasco_id $costillas_id $ensalada_id $limonada_id"
echo "Dishes of Sushi Zen 88: $california_id $nigiri_id $te_id"
echo "Dishes of Pizzería Bella Napoli: $margarita_id $pepperoni_id $lasana_id $tiramisu_id"
