## Summary
Documents the target tables for `user_db`, `plaza_db`, and `traceability_db`. The running application does not change. `messaging-service` stays without a database.

## Context
Each service needs a known schema before the user stories persist data. The schedule fixes the fields: account data, restaurant, dish, order lines, and one row per order status change. This pull request is the shared description those migrations follow.

## What Changed
- Adds `docs/architecture/database/database-schema.md` with the `CREATE TABLE` statements, checks, and indexes.
- Records which story requires each column.
- States that passwords and the delivery PIN are bcrypt hashes, and that ids across databases are logical references, not foreign keys.
- `main` has no schema document. No application code, migration, or Compose file changes.

## Testing
### Automated
No automated test covers this document. It is Markdown.

### Manual
- Open `docs/architecture/database/database-schema.md` and confirm the three databases, the table list, and that messaging is excluded.
- Compare each `CREATE TABLE` with the `V1` script in the matching service pull request.

## Notes for reviewers
- No payment total is stored. A later total, if one is shown, is `dish.price * order_line.quantity`.
- The first administrator account is not inserted here. The hash is created when login exists.
- Order duration is computed from `order_status_change`, not stored on the order.

## Checklist
- [ ] The document matches the `V1` scripts in `user-service`, `plaza-service`, and `traceability-service`.
- [ ] Table and column names are English.
- [ ] No service folder is added to this repository.