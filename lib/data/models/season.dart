enum Season {
  spring('Spring', '🌱'),
  summer('Summer', '☀️'),
  autumn('Fall', '🍂'),
  winter('Winter', '❄️');

  const Season(this.label, this.emoji);

  final String label;
  final String emoji;
}
