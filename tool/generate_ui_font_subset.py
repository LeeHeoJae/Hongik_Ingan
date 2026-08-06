"""Generate the compact Korean font used by the Flutter UI.

The output contains every character found in the Dart source, test HTML,
the maintained dynamic-content corpus, and printable ASCII. Keeping common
server-provided text in the local font prevents a late network font fallback
when menu, seat, or attendance data first appears.

Run with:
    python tool/generate_ui_font_subset.py

This helper uses ``fonttools`` when installed. Otherwise, set
``FLUTTER_FONT_SUBSET`` to Flutter's bundled ``font-subset`` executable.
"""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_FONT = PROJECT_ROOT / 'assets/fonts/NotoSansKR-Regular.ttf'
OUTPUT_FONT = PROJECT_ROOT / 'assets/fonts/NotoSansKR-Ui.ttf'
DYNAMIC_CORPUS = PROJECT_ROOT / 'tool/font_dynamic_corpus.txt'


def main() -> None:
    dart_text = ''.join(
        path.read_text(encoding='utf-8')
        for path in (PROJECT_ROOT / 'lib').rglob('*.dart')
    )
    fixture_text = ''.join(
        path.read_text(encoding='utf-8')
        for extension in ('*.html', '*.jsp')
        for path in (PROJECT_ROOT / 'assets/test').rglob(extension)
    )
    corpus_text = DYNAMIC_CORPUS.read_text(encoding='utf-8')
    required_characters = ''.join(
        sorted(
            set(
                dart_text
                + fixture_text
                + corpus_text
                + ''.join(chr(code_point) for code_point in range(32, 127))
            )
        )
    )

    if importlib.util.find_spec('fontTools') is None:
        _run_flutter_font_subset(required_characters)
        return

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


def _run_flutter_font_subset(required_characters: str) -> None:
    executable = os.environ.get('FLUTTER_FONT_SUBSET')
    if executable is None or not Path(executable).is_file():
        raise RuntimeError(
            'fonttools is not installed. Set FLUTTER_FONT_SUBSET to Flutter\'s '
            'bundled font-subset executable.'
        )

    code_points = ' '.join(
        _font_subset_token(character) for character in required_characters
    )
    subprocess.run(
        [executable, str(OUTPUT_FONT), str(SOURCE_FONT)],
        input=f'{code_points}\n',
        text=True,
        encoding='utf-8',
        check=True,
    )


def _font_subset_token(character: str) -> str:
    code_point = ord(character)
    is_required = (
        32 <= code_point <= 126
        or 0x3130 <= code_point <= 0x318F
        or 0xAC00 <= code_point <= 0xD7A3
    )
    prefix = '' if is_required else 'optional:'
    return f'{prefix}{code_point}'


if __name__ == '__main__':
    main()
