---
description: "Use when debugging or extending receipt OCR, ticket parsing, supermarket heuristics, discount handling, chunked OCR, or ticket-product matching. Covers Lidl, Dia, parser logs, quantities, discounts, and footer detection."
applyTo: "frontend/frontend/lib/services/ticket_parser_service.dart, frontend/frontend/lib/screens/ticket_scanner_screen.dart, frontend/frontend/lib/screens/matchmaker_screen.dart, backend/routers/receipts.py"
---
# Receipt OCR Instructions

- Use real ticket screenshots and runtime logs as the primary debugging source.
- Treat OCR chunk coordinates as local to each crop. Never sort rows across chunks using those coordinates.
- Separate these concepts explicitly: line total, unit price, quantity, discount, and weight detail.
- When an item disappears after being detected, inspect later filtering or discount application before changing OCR grouping.
- Stop item parsing before totals, VAT breakdown, payment rows, footer text, and coupon sections.
- Prefer supermarket-specific heuristics when a layout is stable enough to justify them.
- Preserve enough metadata for manual correction in the matchmaker flow.