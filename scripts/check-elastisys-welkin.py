"""
Pre-commit hook to check that we use Elastisys Welkin® consistently, since
that is what we trademarked. Usage of Welkin (without ®) is okay.
"""
import sys
import re

pattern = re.compile(r'(?<!Elastisys )\bWelkin®')

for filename in sys.argv[1:]:
    with open(filename, 'r', encoding="utf-8") as f:
        for line in f:
            if pattern.search(line):
                print(f"❌ Only use 'Elastisys Welkin®' or 'Welkin' in {filename}: {line.strip()}")
                sys.exit(1)  # Reject commit

sys.exit(0)  # Allow commit
