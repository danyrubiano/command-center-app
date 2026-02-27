with open("lib/features/player/presentation/pages/player_page.dart", "r") as f:
    text = f.read()

count = 0
prev = 0
for line_num, line in enumerate(text.splitlines(), start=1):
    for char in line:
        if char == '{':
            count += 1
        elif char == '}':
            count -= 1
    if count != prev:
        print(f"Line {line_num}: count changed to {count}")
    prev = count
