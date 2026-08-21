import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'

const root = new URL('../', import.meta.url)
const read = async (path) => readFile(new URL(path, root), 'utf8')

const canonicalUrl = 'https://zenche.top/'

test('homepage exposes one aligned canonical and factual software metadata', async () => {
  const html = await read('index.html')
  const canonicalMatches = [
    ...html.matchAll(/<link\s+rel="canonical"\s+href="([^"]+)"\s*\/>/g),
  ]
  assert.equal(canonicalMatches.length, 1)
  assert.equal(canonicalMatches[0][1], canonicalUrl)
  assert.match(
    html,
    /<meta property="og:image" content="https:\/\/zenche\.top\/favicon\.png" \/>/,
  )
  assert.match(
    html,
    /<meta name="twitter:image" content="https:\/\/zenche\.top\/favicon\.png" \/>/,
  )

  const jsonLdText = html.match(
    /<script type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/,
  )?.[1]
  assert.ok(jsonLdText, 'missing SoftwareApplication JSON-LD')
  const application = JSON.parse(jsonLdText)
  assert.equal(application['@type'], 'SoftwareApplication')
  assert.equal(application.name, '帧澈 ZENCHE')
  assert.equal(application.url, canonicalUrl)
  assert.equal(application.softwareVersion, '1.5.14')
  assert.equal(
    application.downloadUrl,
    'https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.14',
  )
  assert.equal(application.offers?.price, '0')
  assert.equal(application.offers?.priceCurrency, 'USD')
  assert.match(application.description, /50 款/)
  assert.match(application.description, /实机验证持续进行中/)
})

test('robots and sitemap are crawlable static files with matching canonical signals', async () => {
  const [robots, sitemap] = await Promise.all([
    read('public/robots.txt'),
    read('public/sitemap.xml'),
  ])
  assert.equal(
    robots,
    'User-agent: *\nAllow: /\n\nSitemap: https://zenche.top/sitemap.xml\n',
  )
  assert.doesNotMatch(robots, /<html|<!doctype/i)
  assert.match(sitemap, /^<\?xml version="1\.0" encoding="UTF-8"\?>/)
  assert.doesNotMatch(sitemap, /<html|<!doctype/i)
  const locations = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(
    (match) => match[1],
  )
  assert.deepEqual(locations, [canonicalUrl])
  assert.doesNotMatch(sitemap, /\/redeem/)
})

test('published version, six download assets, and camera-profile counts stay factual', async () => {
  const [site, cameras, download] = await Promise.all([
    read('src/data/site.ts'),
    read('src/components/Cameras.vue'),
    read('src/components/Download.vue'),
  ])
  assert.match(site, /version: 'V1\.5\.14'/)

  const assets = [
    ['ZENCHE-1.5.14-android.apk', '3_346_729'],
    ['ZENCHE-1.5.14-ios-unsigned.ipa', '4_613_937'],
    ['ZENCHE-1.5.14-HarmonyOS.hap', '4_545_876'],
    ['ZENCHE-1.5.14-macOS-arm64.dmg', '67_407_512'],
    ['ZENCHE-1.5.14-Windows-x64-Setup.exe', '90_921_100'],
    ['ZENCHE-1.5.14-Windows-x64.zip', '110_175_835'],
  ]
  for (const [fileName, bytes] of assets) {
    assert.ok(site.includes(fileName), `missing download asset ${fileName}`)
    assert.match(site, new RegExp(`bytes: ${bytes}`))
  }

  const modelsFor = (brand, nextBrand) => {
    const start = site.indexOf(`brand: '${brand}'`)
    assert.notEqual(start, -1, `missing camera brand ${brand}`)
    const end = nextBrand ? site.indexOf(`brand: '${nextBrand}'`, start) : site.length
    assert.notEqual(end, -1, `missing camera brand boundary ${nextBrand}`)
    const section = site.slice(start, end)
    return [...section.matchAll(/models:\s*\[([^\]]+)\]/g)].flatMap((match) =>
      [...match[1].matchAll(/'([^']+)'/g)].map((model) => model[1]),
    )
  }

  assert.equal(modelsFor('Nikon', 'Sony α').length, 20)
  assert.equal(modelsFor('Sony α', 'Canon EOS R').length, 16)
  assert.equal(modelsFor('Canon EOS R').length, 14)
  assert.match(cameras, /50 款机型档案（Nikon 20、Sony 16、Canon 14）/)
  assert.match(cameras, /不代表所有硬件组合均已完成实机验证/)
  assert.match(
    download,
    /github\.com\/Tauber01\/ZENCHE\/blob\/main\/docs\/releases\/v1\.5\.14\.md/,
  )
})
