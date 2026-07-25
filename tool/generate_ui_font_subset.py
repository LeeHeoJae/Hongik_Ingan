"""Generate the compact Korean font used by the initial Flutter UI.

The output contains every character found in the Dart source plus printable
ASCII. Dynamic text, such as course names and menus, uses Flutter's normal
font fallback when it contains a character outside this subset.

Run with:
    python tool/generate_ui_font_subset.py

This helper requires the local ``fonttools`` package. The full source font is
kept so the subset can be regenerated when static UI copy changes.
"""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_FONT = PROJECT_ROOT / 'assets/fonts/NotoSansKR-Regular.ttf'
OUTPUT_FONT = PROJECT_ROOT / 'assets/fonts/NotoSansKR-Ui.ttf'


def main() -> None:
    source_text = ''.join(
        path.read_text(encoding='utf-8')
        for path in (PROJECT_ROOT / 'lib').rglob('*.dart')
    )
    required_characters = ''.join(
        sorted(
            set(
                source_text
                + ''.join(chr(code_point) for code_point in range(32, 127))
            )
        )
    )

    with tempfile.NamedTemporaryFile(
        mode='w', encoding='utf-8', suffix='.txt', delete=False
    ) as character_file:
        character_file.write(required_characters)
        character_file_path = Path(character_file.name)

    try:
        subprocess.run(
            [
                sys.executable,
                '-m',
                'fontTools.subset',
                str(SOURCE_FONT),
                f'--text-file={character_file_path}',
                f'--output-file={OUTPUT_FONT}',
                '--layout-features=*',
                '--name-IDs=*',
                '--name-legacy',
                '--glyph-names',
            ],
            check=True,
        )
    finally:
        character_file_path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
