import csv

input_file = '/Users/seg/Shemais/Shemais/zawolf_hr/zawolf_ready_import.csv'
output_file = '/Users/seg/.gemini/antigravity-ide/brain/fbc945f6-2ea3-4eb8-9e31-a66386b61662/employee_import_preview.md'

with open(input_file, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    rows = list(reader)

with open(output_file, 'w', encoding='utf-8') as f:
    f.write("# Employee Accounts to Add\n\n")
    f.write("| Email | Name | Code | Role | Department | Position | Location ID | Salary | Currency | Manager Code |\n")
    f.write("|-------|------|------|------|------------|----------|-------------|--------|----------|--------------|\n")
    for row in rows:
        # row: email,displayName,employeeId,role,department,position,locationId,locationName,baseMonthlySalary,salaryCurrency,managerId,managerName
        email = row[0]
        name = row[1]
        code = row[2]
        role = row[3]
        dept = row[4]
        pos = row[5]
        # Set locationId to 'seg'
        loc_id = "SEG"
        # Set salary to 0, currency to EGP
        salary = "0"
        currency = "EGP"
        manager = row[10]
        
        f.write(f"| {email} | {name} | {code} | {role} | {dept} | {pos} | {loc_id} | {salary} | {currency} | {manager} |\n")

print("Done")
