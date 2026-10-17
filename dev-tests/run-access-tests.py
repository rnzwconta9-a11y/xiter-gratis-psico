#!/usr/bin/env python3
"""Test actual access routing and AppState using Swift and native API test doubles."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
app = (root / 'ThreeOneOSFive/App.swift').read_text()
state = app[app.index('class AppState: ObservableObject {'):]
utils = (root / 'ThreeOneOSFive/helpers/Utils.swift').read_text()
status = utils[utils.index('enum ExploitStatus: Equatable {'):utils.index('\nenum AppPaths {')]
sources = [
    (root / 'ThreeOneOSFive/helpers/SupportPolicy.swift').read_text(),
    (root / 'ThreeOneOSFive/helpers/KernelExploit.swift').read_text(),
    status, state,
    (root / 'dev-tests/AccessRoutingHarness.swift').read_text(),
]
subprocess.run(
    ['docker', 'run', '--rm', '-i', 'swift:6.0.3-jammy', 'bash', '-lc',
     'cat > /tmp/rnzw-access.swift && swiftc -swift-version 5 -parse-as-library '
     '/tmp/rnzw-access.swift -o /tmp/rnzw-access && /tmp/rnzw-access'],
    input='\n'.join(sources), text=True, check=True,
)
