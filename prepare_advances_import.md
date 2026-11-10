# How to Prepare Your Advances Excel for Import

## Your Current Format
Your Excel has multiple advances per farmer in a ledger format. We need to convert it to a simple format.

## Required Format for Import

Create a new Excel file with these columns:

| Farmer Name | Phone | Amount | Date | Notes |
|-------------|-------|--------|------|-------|
| Richard Butahurira | | 500000 | 22/7/2026 | First advance |
| Richard Butahurira | | 700000 | 7/9/2026 | Second advance |
| Tabaro | | 500000 | 5/8/2026 | First advance |
| Tabaro | | 500000 | 14/8/2026 | Second advance |
| ...and so on... | | | | |

## Steps to Convert Your Data:

1. **Each advance date gets its own row**
   - Richard Butahurira had advances on 22/7/2026 and 7/9/26
   - Create 2 separate rows for him

2. **Skip the total rows**
   - Don't include rows that show totals or balances

3. **Handle missing dates**
   - If date says "ezeyima", use the last known date or skip

4. **Remove currency symbols**
   - Change `[$UGX] 500,000` to just `500000`
   - Remove commas

5. **One farmer name per row**
   - Even if same farmer appears multiple times

## Example Conversion:

**From your file:**
```
Richard Butahurira    22/7/2026    [$UGX] 500,000
                      7/9/26       [$UGX] 700,000
                      TOTAL        [$UGX] 1,200,000
```

**Should become:**
```
Row 1: Richard Butahurira, , 500000, 22/7/2026, 
Row 2: Richard Butahurira, , 700000, 7/9/2026, 
```

## Quick Way:

I can help you with a script to do this automatically, or you can:
1. Create a new Excel sheet
2. Copy each farmer name and advance date as a separate row
3. Make sure to have all these columns: Name, Phone, Amount, Date, Notes
4. Save and import

Would you like me to create a script to automatically convert your file format?
