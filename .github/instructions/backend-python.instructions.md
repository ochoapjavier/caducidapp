---
description: "Use when editing FastAPI routers, services, repositories, schemas, auth dependencies, or SQLAlchemy models in the backend. Covers API layering, hogar scoping, and safe persistence changes."
applyTo: "backend/**/*.py"
---
# Backend Python Instructions

- Preserve the router -> service -> repository separation.
- Routers should validate input, map HTTP errors, and delegate business logic.
- Services should contain business rules, permission-sensitive workflows, and orchestration.
- Repositories should stay focused on persistence queries and updates.
- Keep hogar scoping explicit in queries and service calls.
- Reuse existing schema patterns before inventing new response shapes.
- If a backend change affects the frontend contract, call it out clearly in the final summary.
- Avoid silent behavior changes in inventory, receipts, notifications, or multihogar logic.