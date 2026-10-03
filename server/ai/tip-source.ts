import { load } from 'cheerio';
import { readSourcePage, trustedSourceUrl, type ReaderOptions } from '../ingestion/reader.ts';
import { MAX_EXTRACTION_INPUT_CHARS } from './openrouter.ts';

/** Reuse the source reader's allowlist, byte limit, cache and deadline for submitted links. */
export async function readTipSource(
  raw: string,
  options: ReaderOptions = {},
): Promise<{ text?: string; reason?: string }> {
  let url: string;
  try {
    url = trustedSourceUrl(raw);
  } catch {
    // Other public URLs may still be investigated through the bounded provider search.
    return {};
  }
  try {
    const page = await readSourcePage(url, options);
    const $ = load(page.html);
    $('script,style,noscript,nav,footer,header,iframe,form').remove();
    const content = $('main').first().length ? $('main').first() : $('body');
    content.find('br').replaceWith('\n');
    content.find('p,div,section,article,h1,h2,h3,li,tr').append('\n');
    const text = content
      .text()
      .split('\n')
      .map((line) => line.replace(/\s+/g, ' ').trim())
      .filter(Boolean)
      .join('\n');
    if (!text) return { reason: 'Poveznica nema čitljiv sadržaj za AI provjeru.' };
    if (text.length > MAX_EXTRACTION_INPUT_CHARS)
      return {
        reason: `Sadržaj poveznice prelazi ${MAX_EXTRACTION_INPUT_CHARS} znakova i nije poslan ni skraćen; potrebna je provjera izvora.`,
      };
    return { text };
  } catch {
    return {
      reason:
        'Sadržaj poveznice nije dohvaćen; prijedlog se može pripremiti samo iz podataka u dojavi. Potrebna je provjera izvora.',
    };
  }
}
