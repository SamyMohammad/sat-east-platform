// Server-side identity stamp (SEC-02 option): writes the student's id into every page, so a
// downloaded or leaked file is traceable. Uses the maintained pdf-lib fork.
import { degrees, PDFDocument, rgb, StandardFonts } from 'npm:@cantoo/pdf-lib@2.11.1';

/**
 * Stamps `label` diagonally (tiled) on every page plus a small footer line.
 * `label` must be WinAnsi text (Latin): the standard fonts cannot draw Arabic, and pdf-lib does
 * no Arabic shaping. Use the short id / phone tail, not the student's name.
 */
export async function stampPdf(input: Uint8Array, label: string, footer: string): Promise<Uint8Array<ArrayBuffer>> {
  // The fork silently writes unsupported characters as "?" (a stamp reading "????" traces no one),
  // so refuse anything outside printable ASCII instead.
  if (/[^\x20-\x7E]/.test(label + footer)) throw new Error('stamp text must be printable ASCII');
  const doc = await PDFDocument.load(input);
  const font = await doc.embedFont(StandardFonts.HelveticaBold);
  const size = 22;
  for (const page of doc.getPages()) {
    const { width, height } = page.getSize();
    const step = 170;
    for (let y = -height; y < height * 2; y += step) {
      for (let x = -width; x < width * 2; x += step * 2) {
        page.drawText(label, {
          x, y, size, font, rotate: degrees(35), color: rgb(0.5, 0.5, 0.5), opacity: 0.12,
        });
      }
    }
    page.drawText(footer, { x: 24, y: 12, size: 8, font, color: rgb(0.4, 0.4, 0.4), opacity: 0.8 });
  }
  return await doc.save() as Uint8Array<ArrayBuffer>;
}

/** Sample notes PDF for tests and the sandbox (no binary fixtures in git). */
export async function makeSamplePdf(pages: number): Promise<Uint8Array<ArrayBuffer>> {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  for (let i = 1; i <= pages; i++) {
    const page = doc.addPage([595, 842]); // A4 portrait
    page.drawText(`Linear Equations - Notes, page ${i} of ${pages}`, { x: 50, y: 780, size: 18, font: bold });
    for (let l = 0; l < 30; l++) {
      page.drawText(`${l + 1}. Solve 3x + ${l} = ${2 * l + 9}. Subtract ${l} from both sides, then divide by 3.`, {
        x: 50, y: 740 - l * 22, size: 11, font,
      });
    }
    page.drawRectangle({ x: 50, y: 60, width: 495, height: 2, color: rgb(0.2, 0.3, 0.8) });
  }
  return await doc.save() as Uint8Array<ArrayBuffer>;
}
