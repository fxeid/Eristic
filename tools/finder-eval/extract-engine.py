#!/usr/bin/env python3
"""Extract the on-device engine (first pass + second pass) from the app into Engine.swift so it compiles on macOS."""
import re, sys, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
vm = (root / "Eristic/ViewModels/FallacyFinderVM.swift").read_text()
cv = re.search(r'// MARK: - ChunkVerdict.*?\n}\n', vm, re.S).group(0)
start = vm.rfind('#if canImport(FoundationModels)'); end = vm.rfind('#endif')
eng = vm[start + len('#if canImport(FoundationModels)'):end]
eng = eng.replace('static let instructions: String = """', 'static var instructions: String = """')
ref = (root / "Eristic/ViewModels/FallacyRefineEngine.swift").read_text()
rs = ref.find('#if canImport(FoundationModels)'); re_ = ref.rfind('#endif')
refine = ref[rs + len('#if canImport(FoundationModels)'):re_].replace('import FoundationModels\n', '')
out_text = "import Foundation\nimport FoundationModels\n\n" + cv + "\n" + eng + "\n" + refine
out_text = out_text.replace('@available(iOS 26.0, *)\n', '')
out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "Engine.swift")
out.write_text(out_text)
print("wrote", out)
