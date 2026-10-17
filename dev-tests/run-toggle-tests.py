#!/usr/bin/env python3
"""Compile the actual toggle controller in official Swift, replacing only iOS APIs/Combine.
Requires Docker; tests file round trips through a device-service test double, not iOS itself.
"""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
controller = (root / 'ThreeOneOSFive/helpers/PanelExecutorStore.swift').read_text()
controller = controller.replace('import Combine\n', '')
harness = (root / 'dev-tests/PanelToggleHarness.swift').read_text()
subprocess.run(
    ['docker', 'run', '--rm', '-i', 'swift:6.0.3-jammy', 'bash', '-lc',
     'cat > /tmp/rnzw-toggle.swift && swiftc -swift-version 5 -parse-as-library '
     '/tmp/rnzw-toggle.swift -o /tmp/rnzw-toggle && /tmp/rnzw-toggle'],
    input=controller + '\n' + harness, text=True, check=True,
)
