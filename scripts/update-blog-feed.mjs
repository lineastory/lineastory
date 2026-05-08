import fs from 'node:fs';
import path from 'node:path';

const FEED_URL = 'https://rss.blog.naver.com/heartart1.xml';
const API = 'https://api.rss2json.com/v1/api.json?rss_url=' + encodeURIComponent(FEED_URL);
const OUT_PATH = path.join('data', 'recent-posts.json');
const MAX_ITEMS = 6;
const DESC_MAX = 200;

function stripHtml(s) {
  return String(s || '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

const res = await fetch(API);
if (!res.ok) {
  console.error('HTTP', res.status, await res.text());
  process.exit(1);
}
const data = await res.json();
if (data.status !== 'ok' || !Array.isArray(data.items)) {
  console.error('Unexpected response:', data);
  process.exit(1);
}

const items = data.items.slice(0, MAX_ITEMS).map(it => {
  const desc = stripHtml(it.description);
  return {
    title: stripHtml(it.title),
    link: it.link,
    pubDate: it.pubDate,
    thumbnail: it.thumbnail || '',
    description: desc.length > DESC_MAX ? desc.slice(0, DESC_MAX).trim() + '…' : desc,
  };
});

const out = { updatedAt: new Date().toISOString(), items };
fs.mkdirSync(path.dirname(OUT_PATH), { recursive: true });
fs.writeFileSync(OUT_PATH, JSON.stringify(out, null, 2) + '\n', 'utf8');
console.log(`Wrote ${items.length} item(s) to ${OUT_PATH}.`);
