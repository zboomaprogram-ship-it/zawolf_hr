import csv

input_file = '/Users/seg/Shemais/Shemais/zawolf_hr/zawolf_ready_import.csv'
output_file = '/Users/seg/Shemais/Shemais/zawolf_hr/zawolf_ready_import_updated.csv'

with open(input_file, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    rows = list(reader)

with open(output_file, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    for row in rows:
        row[6] = "SEG"  # locationId
        row[8] = "0"    # baseMonthlySalary
        row[9] = "EGP"  # salaryCurrency
        writer.writerow(row)

import os
os.replace(output_file, input_file)
print("Updated CSV")
