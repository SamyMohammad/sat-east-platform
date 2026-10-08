// HLS media-playlist rewrite: every segment line becomes an absolute (signed) URL. Tag lines and
// the relative key URI ("key") are left as they are, so the key keeps resolving to the
// token-scoped key route next to the playlist.

export async function rewriteMediaPlaylist(
  text: string, segmentUrl: (name: string) => Promise<string>,
): Promise<string> {
  const lines = text.split(/\r?\n/);
  const out: string[] = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === '' || trimmed.startsWith('#')) {
      out.push(line);
      continue;
    }
    // Only plain file names are expected from the pipeline; anything else is refused so a
    // crafted playlist cannot make the server sign arbitrary storage paths.
    if (!/^[A-Za-z0-9_-]+\.ts$/.test(trimmed)) throw new Error(`unexpected segment uri: ${trimmed}`);
    out.push(await segmentUrl(trimmed));
  }
  return out.join('\n');
}
