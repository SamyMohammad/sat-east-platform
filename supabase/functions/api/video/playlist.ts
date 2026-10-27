// Ported from the HLS spike; errors deliberately omit private playlist content.
export async function rewriteMediaPlaylist(text: string, segmentUrl: (name: string) => Promise<string>): Promise<string> {
  const out: string[] = [];
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (trimmed === '' || trimmed.startsWith('#')) {
      out.push(line);
      continue;
    }
    if (!/^[A-Za-z0-9_-]+\.ts$/.test(trimmed)) throw new Error('Unexpected segment URI.');
    out.push(await segmentUrl(trimmed));
  }
  return out.join('\n');
}
