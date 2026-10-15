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

for email in pedro.martinez@example.com sofia.herrera@example.com kenji.morales@example.com \
    valentina.rossi@example.com andres.torres@example.com \
    camila.restrepo@example.com mateo.vargas@example.com; do
  login "$email" "$seed_password" > /dev/null
done

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
  mateo.vargas@example.com CUSTOMER "$mateo_id" -
echo
echo "Restaurants: $parrilla_id La Parrilla de Carlos, $sushi_id Sushi Zen 88, $napoli_id Pizzería Bella Napoli"
echo "Dishes of La Parrilla de Carlos: $churrasco_id $costillas_id $ensalada_id $limonada_id"
echo "Dishes of Sushi Zen 88: $california_id $nigiri_id $te_id"
echo "Dishes of Pizzería Bella Napoli: $margarita_id $pepperoni_id $lasana_id $tiramisu_id"
