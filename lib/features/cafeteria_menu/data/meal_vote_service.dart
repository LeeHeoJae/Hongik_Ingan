String normalizedVoteItems(List<String> items) => items
    .map((item) => item.replaceAll(RegExp(r'\s+'), ' ').trim())
    .where((item) => item.isNotEmpty)
    .join('\n');
