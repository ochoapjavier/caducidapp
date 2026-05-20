---
name: "Debug Ticket OCR"
description: "Debug a receipt OCR or parser issue using runtime logs, ticket screenshots, row grouping, filtering logic, and supermarket-specific heuristics."
agent: "Receipts Specialist"
argument-hint: "Paste the logs, describe the wrong products, and attach the ticket image if available"
---
Debug the receipt OCR or parser issue.

Requirements:
- Use the provided logs and screenshot as the main evidence.
- Identify whether the failure is OCR, row grouping, parsing, discount logic, deduplication, or post-filtering.
- Fix the root cause with minimal collateral changes.
- Explain what exact products or rows were affected.

Return:
- Root cause
- Change made
- Expected products or behaviors after the fix