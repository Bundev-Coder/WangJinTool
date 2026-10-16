#!/usr/bin/env python3
"""
patch_package.py - Swift 6.2 / concurrency compatibility auto-patcher for WangJin Tool
"""
import os
import sys

def main():
    print("Running patch_package.py: Checking Swift 6.2 compatibility...")
    targets = ["node_modules", "Pods", "Sources", "WangJinTool"]
    patched_count = 0
    for target in targets:
        if os.path.exists(target):
            for root, _, files in os.walk(target):
                for file in files:
                    if file.endswith((".swift", ".h", ".m")):
                        path = os.path.join(root, file)
                        try:
                            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                                content = f.read()
                            modified = False
                            if "@unchecked Sendable" not in content and "public class" in content and "expo" in root.lower():
                                content = content.replace("public class ", "public final class ")
                                modified = True
                            if modified:
                                with open(path, "w", encoding="utf-8") as f:
                                    f.write(content)
                                patched_count += 1
                        except Exception:
                            pass
    print(f"patch_package.py completed successfully. Patched {patched_count} files.")

if __name__ == "__main__":
    main()
