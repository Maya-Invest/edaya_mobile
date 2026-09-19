import 'dart:io';

class DesignReviewShot {
  const DesignReviewShot({
    required this.relativePath,
    required this.title,
    required this.description,
  });

  final String relativePath;
  final String title;
  final String description;
}

void writeDesignReviewPack({
  required Directory outputDir,
  required List<DesignReviewShot> shots,
  required String localeLabel,
}) {
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  final readme = StringBuffer()
    ..writeln('# Teacher — design review pack')
    ..writeln()
    ..writeln('Generated: $generatedAt')
    ..writeln('Data: mock fixtures (no API)')
    ..writeln('Locale: $localeLabel')
    ..writeln()
    ..writeln('Open `index.html` in a browser to browse screenshots.')
    ..writeln()
    ..writeln('## Screens')
    ..writeln();

  for (final shot in shots) {
    readme.writeln('- **${shot.title}** — `${shot.relativePath}`');
    if (shot.description.isNotEmpty) {
      readme.writeln('  ${shot.description}');
    }
  }

  File('${outputDir.path}/README.md').writeAsStringSync(readme.toString());

  final cards = shots
      .map(
        (shot) =>
            '''
    <figure>
      <img src="${shot.relativePath}" alt="${_escapeHtml(shot.title)}" loading="lazy" />
      <figcaption>
        <strong>${_escapeHtml(shot.title)}</strong>
        <span>${_escapeHtml(shot.description)}</span>
      </figcaption>
    </figure>''',
      )
      .join('\n');

  final html =
      '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Edaya Guardian Prototype — design review</title>
  <style>
    :root {
      color-scheme: light;
      font-family: Inter, system-ui, sans-serif;
      background: #f8fafc;
      color: #0f172a;
    }
    body {
      margin: 0;
      padding: 2rem;
    }
    header {
      max-width: 1200px;
      margin: 0 auto 2rem;
    }
    h1 {
      margin: 0 0 0.5rem;
      font-size: 1.75rem;
    }
    .meta {
      color: #475569;
      font-size: 0.95rem;
      line-height: 1.5;
    }
    .grid {
      display: grid;
      gap: 1.5rem;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      max-width: 1200px;
      margin: 0 auto;
    }
    figure {
      margin: 0;
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 1rem;
      overflow: hidden;
      box-shadow: 0 10px 30px rgba(15, 23, 42, 0.06);
    }
    img {
      display: block;
      width: 100%;
      height: auto;
      background: #e2e8f0;
    }
    figcaption {
      padding: 1rem 1.1rem 1.2rem;
      display: grid;
      gap: 0.35rem;
    }
    figcaption span {
      color: #64748b;
      font-size: 0.9rem;
    }
  </style>
</head>
<body>
  <header>
    <h1>Edaya Guardian Prototype — design review</h1>
    <p class="meta">
      Generated $generatedAt<br />
      Data: mock fixtures (no API)<br />
      Locale: $localeLabel
    </p>
  </header>
  <section class="grid">
$cards
  </section>
</body>
</html>
''';

  File('${outputDir.path}/index.html').writeAsStringSync(html);
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
