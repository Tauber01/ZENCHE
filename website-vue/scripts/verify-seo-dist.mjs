import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const root = new URL('../', import.meta.url)
const read = async (path) => readFile(new URL(path, root), 'utf8')

const [sourceRobots, sourceSitemap, html, robots, sitemap] = await Promise.all([
  read('public/robots.txt'),
  read('public/sitemap.xml'),
  read('dist/index.html'),
  read('dist/robots.txt'),
  read('dist/sitemap.xml'),
])

assert.equal(robots, sourceRobots, 'dist/robots.txt differs from the reviewed source')
assert.equal(sitemap, sourceSitemap, 'dist/sitemap.xml differs from the reviewed source')
assert.doesNotMatch(robots, /<html|<!doctype/i)
assert.doesNotMatch(sitemap, /<html|<!doctype/i)
assert.match(html, /<link rel="canonical" href="https:\/\/zenche\.top\/" \/>/)

const jsonLdText = html.match(
  /<script type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/,
)?.[1]
assert.ok(jsonLdText, 'dist/index.html is missing SoftwareApplication JSON-LD')
assert.equal(JSON.parse(jsonLdText).softwareVersion, '1.5.14')

console.log('SEO dist verification passed: canonical, JSON-LD, robots.txt and sitemap.xml')
